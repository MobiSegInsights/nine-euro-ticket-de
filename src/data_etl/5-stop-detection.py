from pathlib import Path
import pandas as pd
import time
import os
os.environ['JAVA_HOME'] = "C:/Java/jdk-1.8"
from tqdm import tqdm
from pyspark.sql import SparkSession
import sys
import pyspark.sql.functions as F
from pyspark.sql.types import *
from pyspark import SparkConf
from infostop import Infostop
import sqlalchemy


ROOT_dir = Path(__file__).parent.parent.parent
sys.path.append(ROOT_dir)
sys.path.insert(0, os.path.join(ROOT_dir, 'lib'))

import workers as workers

# Set up pyspark
os.environ['PYSPARK_PYTHON'] = sys.executable
os.environ['PYSPARK_DRIVER_PYTHON'] = sys.executable
# Create new context
spark_conf = SparkConf().setMaster("local[18]").setAppName("MobiSeg")
spark_conf.set("spark.executor.heartbeatInterval","3600s")
spark_conf.set("spark.network.timeout","7200s")
spark_conf.set("spark.sql.files.ignoreCorruptFiles","true")
spark_conf.set("spark.driver.memory", "56g")
spark_conf.set("spark.driver.maxResultSize", "0")
spark_conf.set("spark.executor.memory","8g")
spark_conf.set("spark.memory.fraction", "0.6")
spark_conf.set("spark.sql.session.timeZone", "UTC")
spark = SparkSession.builder.config(conf=spark_conf).getOrCreate()
java_version = spark._jvm.System.getProperty("java.version")
print(f"Java version used by PySpark: {java_version}")
print('Web UI:', spark.sparkContext.uiWebUrl)


# infostop function
R1, R2, MIN_STAY, MAX_TIME_BETWEEN = 30, 30, 15, 3  # meters, meters, minutes, hours


def infostop_per_user(key, data):
    model = Infostop(
        r1=R1,
        r2=R2,
        label_singleton=True,
        min_staying_time=MIN_STAY*60,
        max_time_between=MAX_TIME_BETWEEN*60*60,
        min_size=2,
        min_spacial_resolution=0,
        distance_metric='haversine',
        weighted=False,
        weight_exponent=1,
        verbose=False,)
    x = data.loc[~(((data['latitude'] > 84) | (data['latitude'] < -80)) | ((data['longitude'] > 180) | (data['longitude'] < -180))), :]
    x = x.sort_values(by='timestamp').drop_duplicates(subset=['latitude', 'longitude', 'timestamp']).reset_index(drop=True)
    x = x.dropna()

    x['t_seg'] = x['timestamp'].shift(-1)
    x.loc[x.index[-1], 't_seg'] = x.loc[x.index[-1],'timestamp']+1
    x['n'] = x.apply(lambda x: range(int(x['timestamp']),
                                     min(int(x['t_seg']), x['timestamp']+(MAX_TIME_BETWEEN*60*60)),
                                     (MAX_TIME_BETWEEN*60*60-1)), axis=1)
    x = x.explode('n')
    x['timestamp'] = x['n'].astype(float)
    x = x[['latitude', 'longitude', 'timestamp']].dropna() # ,'timezone'

    try:
        labels = model.fit_predict(x[['latitude', 'longitude', 'timestamp']].values)
    except:
        return pd.DataFrame([],
                            columns=['device_aid', 'timestamp', 'latitude', 'longitude',
                                     'loc', 'stop_latitude', 'stop_longitude', 'interval']) #,'timezone'

    label_medians = model.compute_label_medians()
    x['loc'] = labels
    x['same_loc'] = x['loc'] == x['loc'].shift()
    # x['same_timezone'] = x['timezone']==x['timezone'].shift()
    x['little_time'] = (x['timestamp'] - x['timestamp'].shift() < MAX_TIME_BETWEEN*60*60)

    x['interval'] = (~(x['same_loc'] & x['little_time'])).cumsum() # & x['same_timezone']

    latitudes = {k: v[0] for k, v in label_medians.items()}
    longitudes = {k: v[1] for k, v in label_medians.items()}
    x['stop_latitude'] = x['loc'].map(latitudes)
    x['stop_longitude'] = x['loc'].map(longitudes)
    x['device_aid'] = key[0]

    # keep only stop locations
    x = x[x['loc'] > 0].copy()

    return x[['device_aid','timestamp','latitude','longitude','loc','stop_latitude','stop_longitude','interval']] #,'timezone'


schema = StructType([StructField('loc', IntegerType()),
                     StructField('timestamp', IntegerType()),
                     StructField('interval', IntegerType()),
                     StructField('latitude', DoubleType()),
                     StructField('longitude', DoubleType()),
                     StructField('device_aid', StringType()),
                     StructField('stop_latitude', DoubleType()),
                     StructField('stop_longitude', DoubleType()),
                    ]) # StructField('timezone',IntegerType()),


class StopDetection:
    def __init__(self):
        self.file_paths_dict = None
        self.user = workers.keys_manager['database']['user']
        self.password = workers.keys_manager['database']['password']
        self.port = workers.keys_manager['database']['port']
        self.db_name = workers.keys_manager['database']['name']

    def file_list(self):
        # File location and structure
        data_folder = 'D:\\MAD_dbs\\raw_data_de\\format_parquet'
        paths = [x[0] for x in os.walk(data_folder)]
        paths = paths[1:]
        self.file_paths_dict = dict()
        for path in paths:
            bt = int(path.split('_')[-1])
            files = os.listdir(path)
            file_paths = [os.path.join(path, f) for f in files]
            self.file_paths_dict[bt] = file_paths   # 300 groups of users

    def stop_batch(self, batch=None):
        engine = sqlalchemy.create_engine(
            f'postgresql://{self.user}:{self.password}@localhost:{self.port}/{self.db_name}?gssencmode=disable')
        print(f'Processing user group {batch}:')
        start = time.time()
        file_paths = self.file_paths_dict[batch]
        df = spark.read.parquet(*file_paths). \
            select('device_aid', 'timestamp', 'latitude', 'longitude')
        stops = df.groupby('device_aid').applyInPandas(infostop_per_user, schema=schema)
        stop_locations = stops.groupby('device_aid', 'interval').agg(F.first('loc').alias('loc'),
                                                                     F.min('timestamp').alias('start'),
                                                                     F.max('timestamp').alias('end'),
                                                                     F.first('stop_latitude').alias('latitude'),
                                                                     F.first('stop_longitude').alias('longitude'),
                                                                     F.count('loc').alias('size'))
        df_stops = stop_locations.toPandas()
        df_stops['batch'] = batch
        # Save data to database
        print("Saving data...")
        # df_stops.to_sql('stops', engine, schema='stops', index=False, if_exists='append',
        #                 method='multi', chunksize=5000)
        df_stops.to_parquet(os.path.join(ROOT_dir, f'dbs/stops/stops_{batch}.parquet'), index=False)
        end = time.time()
        time_elapsed = (end - start) // 60  # in minutes
        print(f"Group {batch} processed and saved in {time_elapsed} minutes.")


if __name__ == '__main__':
    sd = StopDetection()
    sd.file_list()
    # All batches are done
    for batch in range(0, 300):
        sd.stop_batch(batch=batch)
