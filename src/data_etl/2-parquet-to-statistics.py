from pathlib import Path
import pandas as pd
import numpy as np
import random
import os
os.environ['JAVA_HOME'] = "C:/Java/jdk-1.8"
from tqdm import tqdm
from pyspark.sql import SparkSession
import sys
import time
from pyspark import SparkConf
import sqlalchemy
import warnings
warnings.simplefilter(action='ignore', category=FutureWarning)


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

# File location and structure
# data_folder = 'D:\\MAD_dbs\\raw_data_de\\format_parquet_br'
# paths = [x[0] for x in os.walk(data_folder)]
# paths = paths[1:]
# file_paths_list = []
# for path in paths:
#     files = os.listdir(path)
#     file_paths = [os.path.join(path, f) for f in files]
#     file_paths_list.append(file_paths)  # 300 groups of users

# For combined two time periods
file_paths_dict = dict()
data_folder1 = 'D:\\MAD_dbs\\raw_data_de\\format_parquet_r'
paths1 = [data_folder1 + f'\\grp_{x}' for x in range(0, 300)]
data_folder2 = 'D:\\MAD_dbs\\raw_data_de\\format_parquet_br'
paths2 = [data_folder2 + f'\\grp_{x}' for x in range(0, 300)]
for path1, path2, grp in zip(paths1, paths2, range(0, 300)):
    files1 = os.listdir(path1)
    file_paths1 = [os.path.join(path1, f) for f in files1]
    files2 = os.listdir(path2)
    file_paths2 = [os.path.join(path2, f) for f in files2]
    file_paths_dict[grp] = file_paths1 + file_paths2  # 300 groups of users


def data_chunk_stats(data):
    # df.groupby(['date', 'hour']).
    return pd.Series(dict(week=data['week'].values[0],
                          weekday=data['weekday'].values[0],
                          device_count=data['device_aid'].nunique(),
                          rec_count=len(data)))


def data_chunk_stats_ym(data):
    # df.groupby(['date', 'hour']).
    return pd.Series(dict(device_count=data['device_aid'].nunique(),
                          rec_count=len(data)))


def q_completeness(data):
    # df.groupby('device_aid').
    total_hours = 168
    # Overall q
    no_active_days = data['date'].nunique()
    total_days = np.ceil((data.timestamp.max() - data.timestamp.min()) / 3600 / 24 + 1)
    q_day = no_active_days / max(total_days, 1)

    # Weekly q
    def week_q(x):
        no_active_hours = x[['weekday', 'hour']].drop_duplicates().shape[0]
        return pd.Series(dict(q_hour=no_active_hours / total_hours))

    # Only for data lasting less than one year
    if data['week'].nunique() > 1:
        q_hour_df = data.groupby('week').apply(week_q, include_groups=False)
        q_hour_m = q_hour_df['q_hour'].mean()
        q_hour_sd = q_hour_df['q_hour'].std()
    else:
        no_active_hours = data[['weekday', 'hour']].drop_duplicates().shape[0]
        q_hour_m = no_active_hours / total_hours
        q_hour_sd = 0
    # Weekly patterns
    # count_df = data.groupby(['weekday', 'hour']).size().to_frame('count').reset_index()

    return pd.Series(dict(no_active_days=no_active_days, total_days=total_days, q_day=q_day,
                          q_hour_m=q_hour_m, q_hour_sd=q_hour_sd, no_rec=len(data)))


class StatsCompute:
    def __init__(self, num_grps=20, batch=0):
        self.num_grps = num_grps
        self.batch = batch
        self.file_paths_dict = file_paths_dict
        self.df = None
        self.user = workers.keys_manager['database']['user']
        self.password = workers.keys_manager['database']['password']
        self.port = workers.keys_manager['database']['port']
        self.db_name = workers.keys_manager['database']['name']

    def load_data(self):
        print(f"Preparing data batch {self.batch}")
        df = spark.read.parquet(*self.file_paths_dict[self.batch]).\
            select('timestamp', 'device_aid', 'latitude', 'longitude')
        devices = df.select("device_aid").distinct().collect()
        random.seed(68)
        name_group_df = spark.createDataFrame([(row["device_aid"],
                                                random.randint(0, self.num_grps)) for row in devices],
                                              ["device_aid", "grp"])
        self.df = df.join(name_group_df, on="device_aid", how="left")
        print('Data loaded.')

    def data_stats_compute(self, data=None, batch=None, grp=None):
        engine = sqlalchemy.create_engine(
            f'postgresql://{self.user}:{self.password}@localhost:{self.port}/{self.db_name}?gssencmode=disable')
        # Time processing
        timeProc = workers.TimeProcessing(data=data)
        timeProc.time_processing()
        # timeProc.time_zone_parallel()
        # timeProc.convert_to_local_time()
        timeProc.time_enrich()

        # Data-wise statistics prep
        tqdm.pandas()
        df_stats_data = timeProc.data.groupby(['date', 'hour']).progress_apply(data_chunk_stats).reset_index()
        df_stats_data.loc[:, 'batch'] = batch
        df_stats_data.loc[:, 'grp'] = grp
        print("Saving data stats..")
        df_stats_data.to_sql('raw', engine, schema='data_desc', index=False, if_exists='append',
                             method='multi', chunksize=5000)

        # Data-wise statistics prep - By month
        tqdm.pandas()
        df_stats_data = timeProc.data.groupby(['year', 'month']).progress_apply(data_chunk_stats_ym).reset_index()
        df_stats_data.loc[:, 'batch'] = batch
        df_stats_data.loc[:, 'grp'] = grp
        print("Saving data stats..")
        df_stats_data.to_sql('raw_ym', engine, schema='data_desc', index=False, if_exists='append',
                             method='multi', chunksize=5000)

        # Individual-wise statistics
        tqdm.pandas()
        df_q = timeProc.data.groupby('device_aid').progress_apply(q_completeness).reset_index()
        df_q.loc[:, 'batch'] = batch
        df_q.loc[:, 'grp'] = grp
        print("Saving individual stats..")
        df_q.to_sql('raw_indi', engine, schema='data_desc', index=False, if_exists='append',
                    method='multi', chunksize=5000)

    def compute_group(self, grp=None):
        start = time.time()
        print(f"Computing batch {self.batch} - group {grp}...")
        df_g = self.df.filter(self.df["grp"] == grp).toPandas()
        self.data_stats_compute(data=df_g, batch=self.batch, grp=grp)
        end = time.time()
        print(f"Data {self.batch}-{grp} saved in {(end - start) / 60} minutes.")


if __name__ == '__main__':
    sc = StatsCompute(num_grps=6, batch=1)
    sc.load_data()
    for grp in range(0, sc.num_grps):
        sc.compute_group(grp=grp)
