import sys
from pathlib import Path
import os
import pandas as pd
os.environ['USE_PYGEOS'] = '0'
import geopandas as gpd
import time
from tqdm import tqdm
import sqlalchemy


ROOT_dir = Path(__file__).parent.parent
sys.path.append(ROOT_dir)
sys.path.insert(0, os.path.join(ROOT_dir, 'lib'))

import workers

data_folder = os.path.join(ROOT_dir, 'dbs/stop2poi/')
paths2stops = {int(x.split('_')[-1].split('.')[0]): os.path.join(data_folder, x)\
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

    def load_weight(self):
        engine = sqlalchemy.create_engine(
            f'postgresql://{self.user}:{self.password}@localhost:{self.port}/{self.db_name}?gssencmode=disable')
        # self.home = pd.merge(pd.read_sql("""SELECT * FROM weight_rg;""", con=engine),
        #                      pd.read_sql("""SELECT device_aid, latitude, longitude FROM home_r;""", con=engine),
        #                      on='device_aid', how='left')
        self.home = pd.read_sql("""SELECT device_aid, latitude, longitude FROM home_r;""", con=engine)
        self.home.rename(columns={'latitude': 'lat_h', 'longitude': 'lng_h'}, inplace=True)

    def process_and_save(self, batch=None, cols=None):
        data = pd.read_parquet(paths2stops[batch])[cols]
        data.loc[:, 'osm_id'] = data.loc[:, 'osm_id'].astype(int)
        data = pd.merge(data, self.home, on='device_aid', how='left')
        data = pd.merge(data, self.gdf[['osm_id', 'theme', 'lat', 'lng']], on='osm_id', how='left')
        data.dropna(inplace=True)
        data.loc[:, 'month'] = data.loc[:, 'date'].apply(lambda x: int(str(x).split('-')[1]))
        data = data.loc[data['month'] != 10, :]
        data.loc[:, 'period'] = data.loc[:, 'month'].apply(lambda x: 0 if x in (5, 9) else 1)
        # Distance calculation
        tqdm.pandas()
        data.loc[:, 'd_h'] = data.progress_apply(lambda row: workers.haversine(row['lng'], row['lat'],
                                                                               row['lng_h'], row['lat_h']), axis=1)
        data.drop(columns=['lng', 'lat', 'lng_h', 'lat_h'], inplace=True)
        data.to_parquet(os.path.join(ROOT_dir, f'dbs/poi2visits_day/stops_{batch}.parquet'), index=False)


if __name__ == '__main__':
    cols_selected = ['device_aid', 'date', 'dur', 'year', 'week', 'weekday', 'osm_id', 'label']
    vddp = VisitationDayDataPrep()
    print('Load POIs and individual weights')
    vddp.load_pois()
    vddp.load_weight()
    for batch in range(0, 300):
        print(f'Process batch {batch}.')
        start = time.time()
        vddp.process_and_save(batch=batch, cols=cols_selected)
        end = time.time()
        time_elapsed = (end - start)    # in seconds
        print(f"Group {batch} processed and saved in {time_elapsed} seconds.")
