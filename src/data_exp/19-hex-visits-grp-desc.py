from pathlib import Path
import pandas as pd
import time
import os
os.environ['JAVA_HOME'] = "C:/Java/jdk-1.8"
from pyspark.sql import SparkSession
import sys
import pyspark.sql.functions as F
from pyspark.sql.types import *
from pyspark import SparkConf
import numpy as np


ROOT_dir = Path(__file__).parent.parent.parent
sys.path.append(ROOT_dir)
sys.path.insert(0, os.path.join(ROOT_dir, 'lib'))


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


def visit_patterns_hex_date(data):
    data.loc[:, 'date'] = data.loc[:, 'date'].astype(str)
    metrics_dict = dict()
    # osm_id info
    for var in ('date', 'level', 'year', 'month', 'weekday', 'pt_station_num'):
        metrics_dict[var] = data[var].values[0]

    # Visits
    metrics_dict['visit_50'] = 10 ** (np.log10(data['num_visits_wt']).median())
    metrics_dict['visit_25'] = 10 ** (np.nanquantile(np.log10(data['num_visits_wt']), 0.25))
    metrics_dict['visit_75'] = 10 ** (np.nanquantile(np.log10(data['num_visits_wt']), 0.75))

    # Distance
    metrics_dict['d_50'] = 10 ** (np.log10(data['d_ha_wt']).median())
    metrics_dict['d_25'] = 10 ** (np.nanquantile(np.log10(data['d_ha_wt']), 0.25))
    metrics_dict['d_75'] = 10 ** (np.nanquantile(np.log10(data['d_ha_wt']), 0.75))
    return pd.DataFrame(metrics_dict, index=[0])


schema_stats = StructType([
    StructField("date", StringType(), True),
    StructField("level", StringType(), True),
    StructField("year", IntegerType(), True),
    StructField("month", IntegerType(), True),
    StructField("weekday", IntegerType(), True),
    StructField("pt_station_num", IntegerType(), True),
    StructField('visit_25', DoubleType(), True),
    StructField('visit_50', DoubleType(), True),
    StructField('visit_75', DoubleType(), True),
    StructField('d_25', DoubleType(), True),
    StructField('d_50', DoubleType(), True),
    StructField('d_75', DoubleType(), True)
])


if __name__ == '__main__':
    start = time.time()
    data_folder = os.path.join(ROOT_dir, 'dbs/combined_visits_day_did_hex/')
    paths2hex = {x.split('.')[0]: os.path.join(ROOT_dir, data_folder, x)
                 for x in list(os.walk(data_folder))[0][2]}
    paths2hex_list = [v for k, v in paths2hex.items()]
    df = spark.read.parquet(*paths2hex_list)
    print(df.show(5))
    lbs = ['age', 'all', 'birth_f', 'deprivation', 'net_rent', 'pop_density']
    for lb in lbs:
        print(lb)
        df_v = df.filter(df.group == lb). \
            groupby(['date', 'level']).applyInPandas(visit_patterns_hex_date, schema=schema_stats)
        df_v.toPandas().to_parquet(os.path.join(ROOT_dir, f"results/hex_time_series/{lb}.parquet"), index=False)
        delta_t = (time.time() - start) // 60
        print(f"Label {lb} processed and saved in {delta_t} minutes.")
