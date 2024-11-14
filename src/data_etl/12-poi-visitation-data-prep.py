import sys
from pathlib import Path
import os
import pandas as pd
from p_tqdm import p_map

os.environ['USE_PYGEOS'] = '0'
import geopandas as gpd
import time
from tqdm import tqdm
import sqlalchemy

ROOT_dir = Path(__file__).parent.parent
sys.path.append(ROOT_dir)
sys.path.insert(0, os.path.join(ROOT_dir, 'lib'))

import workers

data_folder = os.path.join(ROOT_dir, 'dbs/stop_combined2poi/')
paths2stops = {int(x.split('_')[-1].split('.')[0]): os.path.join(data_folder, x) \
               for x in list(os.walk(data_folder))[0][2]}


class VisitationDayDataPrep:
    def __init__(self):
        self.home = None
        self.gdf = None
        self.user = workers.keys_manager['database']['user']
        self.password = workers.keys_manager['database']['password']
        self.port = workers.keys_manager['database']['port']
        self.db_name = workers.keys_manager['database']['name']

    def load_pois(self):
        engine = sqlalchemy.create_engine(
            f'postgresql://{self.user}:{self.password}@localhost:{self.port}/{self.db_name}?gssencmode=disable')
        # Get pois from database
        self.gdf = gpd.GeoDataFrame.from_postgis(sql="""SELECT osm_id, theme, label, geom FROM poi;""", con=engine)
        self.gdf.loc[:, 'lat'] = self.gdf.geometry.y
        self.gdf.loc[:, 'lng'] = self.gdf.geometry.x

    def load_home(self):
        engine = sqlalchemy.create_engine(
            f'postgresql://{self.user}:{self.password}@localhost:{self.port}/{self.db_name}?gssencmode=disable')
        self.home = pd.read_sql("""SELECT device_aid, latitude, longitude FROM home;""", con=engine)
        self.home.rename(columns={'latitude': 'lat_h', 'longitude': 'lng_h'}, inplace=True)

    def process_and_save(self, batch=None):
        cols = ['device_aid', 'date', 'dur', 'year', 'week', 'weekday', 'osm_id', 'label']
        data = pd.read_parquet(paths2stops[batch])[cols]
        data.loc[:, 'osm_id'] = data.loc[:, 'osm_id'].astype(int)
        data = pd.merge(data, self.home, on='device_aid', how='left')
        data = pd.merge(data, self.gdf[['osm_id', 'theme', 'lat', 'lng']], on='osm_id', how='left')
        data.dropna(inplace=True)
        data.loc[:, 'month'] = data.loc[:, 'date'].apply(lambda x: int(str(x).split('-')[1]))
        data = data.loc[data['month'] != 10, :]
        data.loc[:, 'period'] = data.loc[:, 'month'].apply(lambda x: 1 if x in (6, 7, 8) else 0)
        data.loc[:, 'period'] = data.apply(lambda row: 2 if (row['year'] in (2022, 2023)) &
                                                            (row['month'] == 5) else row['period'], axis=1)
        # Distance calculation
        data.loc[:, 'd_h'] = data.apply(lambda row: workers.haversine(row['lng'], row['lat'],
                                                                      row['lng_h'], row['lat_h']), axis=1)
        data.drop(columns=['lng', 'lat', 'lng_h', 'lat_h'], inplace=True)
        data.to_parquet(os.path.join(ROOT_dir, f'dbs/combined_poi2visits_day/stops_{batch}.parquet'), index=False)

    def process_bulk(self, batches=None, test=False):
        cols = ['device_aid', 'date', 'dur', 'year', 'week', 'weekday', 'osm_id', 'label']
        data = []
        for b in tqdm(batches, desc='Loading'):
            tp = pd.read_parquet(paths2stops[b])[cols]
            tp.loc[:, 'batch'] = b
            if test:
                data.append(tp.sample(1000))
            else:
                data.append(tp)
        data = pd.concat(data)
        data.loc[:, 'osm_id'] = data.loc[:, 'osm_id'].astype(int)
        print('Merge home and osm data.')
        data = pd.merge(data, self.home, on='device_aid', how='left')
        data = pd.merge(data, self.gdf[['osm_id', 'theme', 'lat', 'lng']], on='osm_id', how='left')
        data.dropna(inplace=True)
        data.loc[:, 'month'] = data.loc[:, 'date'].apply(lambda x: int(str(x).split('-')[1]))
        data = data.loc[data['month'] != 10, :]
        data.loc[:, 'period'] = data.loc[:, 'month'].apply(lambda x: 1 if x in (6, 7, 8) else 0)
        data.loc[:, 'period'] = data.apply(lambda row: 2 if (row['year'] in (2022, 2023)) &
                                                            (row['month'] == 5) else row['period'], axis=1)
        # Distance calculation
        tqdm.pandas(desc='Distance to home')
        data.loc[:, 'd_h'] = data.progress_apply(lambda row: workers.haversine(row['lng'], row['lat'],
                                                                               row['lng_h'], row['lat_h']), axis=1)
        data.drop(columns=['lng', 'lat', 'lng_h', 'lat_h'], inplace=True)

        def save_g(group):
            group.to_parquet(os.path.join(ROOT_dir, f'dbs/combined_poi2visits_day/stops_{group.name}.parquet'), index=False)

        data.groupby('batch').apply(save_g, include_groups=False)

    def process_parallel(self):
        for i in range(0, 15):
            print(f'Process group {i + 1}/15.')
            start = time.time()
            batches_and_cols = [(batch, ) for batch in range(i * 20, (i + 1) * 20)]
            p_map(lambda args: self.process_and_save(*args), batches_and_cols)
            end = time.time()
            time_elapsed = (end - start) / 60  # in minutes
            print(f"Group {i + 1} processed and saved in {time_elapsed} minutes.")


if __name__ == '__main__':
    vddp = VisitationDayDataPrep()
    print('Load POIs and home records')
    vddp.load_pois()
    vddp.load_home()
    # vddp.process_parallel()
    num = 28
    for i in range(0, 10):
        print(f'Process group {i + 1}/10.')
        start = time.time()
        vddp.process_bulk(batches=[batch for batch in range(20 + i * num, 20 + (i + 1) * num)])
        end = time.time()
        time_elapsed = (end - start) / 60  # in minutes
        print(f"Group {i + 1} processed and saved in {time_elapsed} minutes.")

    # for batch in range(10, 300):
    #     print(f'Process batch {batch}.')
    #     start = time.time()
    #     vddp.process_and_save(batch=batch, cols=cols_selected)
    #     end = time.time()
    #     time_elapsed = (end - start)  # in seconds
    #     print(f"Group {batch} processed and saved in {time_elapsed} seconds.")
