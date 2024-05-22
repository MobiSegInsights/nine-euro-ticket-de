import sys
from pathlib import Path
import os
import pandas as pd
os.environ['USE_PYGEOS'] = '0'
import geopandas as gpd
import skmob
from skmob.measures.individual import home_location
from p_tqdm import p_map
import time
import numpy as np
import sqlalchemy
from sklearn.neighbors import KDTree


ROOT_dir = Path(__file__).parent.parent
sys.path.append(ROOT_dir)
sys.path.insert(0, os.path.join(ROOT_dir, 'lib'))

import workers

data_folder = os.path.join(ROOT_dir, 'dbs/stops_p/')
paths2stops = {int(x.split('_')[-1].split('.')[0]): os.path.join(data_folder, x)\
               for x in list(os.walk(data_folder))[0][2]}


def indi_traj2home(data_input):
    data = data_input[['device_aid', 'latitude', 'longitude', 'loc', 'localtime', 'l_localtime']].copy()
    data.loc[:, 'time_series'] = data.apply(lambda row: pd.date_range(start=row['localtime'],
                                                                      end=row['l_localtime'], freq='15min'), axis=1)
    df_exploded = data[['device_aid', 'latitude', 'longitude', 'time_series']].explode('time_series')
    tdf = skmob.TrajDataFrame(df_exploded, latitude='latitude', longitude='longitude',
                              datetime='time_series', user_id='device_aid')
    hl_df = home_location(tdf, start_night='22:00', end_night='07:00', show_progress=False)
    hl_df.rename(columns={'uid': 'device_aid', 'lat': 'latitude', 'lng': 'longitude'}, inplace=True)
    hl_df.loc[:, 'home'] = 1
    return hl_df


class Stops2POIs:
    def __init__(self):
        self.data = None
        self.home = None
        self.gdf = None
        self.tree = None
        self.user = workers.keys_manager['database']['user']
        self.password = workers.keys_manager['database']['password']
        self.port = workers.keys_manager['database']['port']
        self.db_name = workers.keys_manager['database']['name']

    def load_pois(self):
        engine = sqlalchemy.create_engine(
            f'postgresql://{self.user}:{self.password}@localhost:{self.port}/{self.db_name}?gssencmode=disable')
        print('Load POI data and create a KD-tree.')
        self.gdf = gpd.GeoDataFrame.from_postgis(sql="""SELECT * FROM poi;""", con=engine)
        self.gdf = self.gdf.to_crs(25832)  # Projection in meter for Germany
        self.gdf.loc[:, 'y'] = self.gdf.geom.y
        self.gdf.loc[:, 'x'] = self.gdf.geom.x
        self.tree = KDTree(self.gdf[["y", "x"]], metric="euclidean")

    def load_stops(self, batch=None, test=False):
        self.data = pd.read_parquet(paths2stops[batch])
        if test:
            inds = self.data.device_aid.unique()
            self.data = self.data.loc[self.data.device_aid.isin(inds[:10000]), :]

    def home_detection_to_stops(self, grp_num=20):
        print('Home detection started.')
        engine = sqlalchemy.create_engine(
            f'postgresql://{self.user}:{self.password}@localhost:{self.port}/{self.db_name}?gssencmode=disable')
        np.random.seed(68)
        device2group = {x: np.random.randint(1, grp_num+1) for x in list(self.data.device_aid.unique())}
        self.data.loc[:, 'home2grp'] = self.data['device_aid'].map(device2group)
        home_list = p_map(indi_traj2home, [g for _, g in self.data.groupby('home2grp', group_keys=True)])
        self.home = pd.concat(home_list)
        self.data = pd.merge(self.data, self.home, on=['device_aid', 'latitude', 'longitude'], how='left')
        self.data['home'] = self.data['home'].fillna(0)
        self.data.drop(columns=['home2grp'], inplace=True)
        print(f"Share of stops that are home records: {len(self.data[self.data['home']==1]) / len(self.data) * 100} %")

        # Save home data
        print('Save home data...')
        home = self.data.loc[self.data['home'] == 1, ['device_aid', 'loc', 'latitude', 'longitude']].\
            drop_duplicates(subset=['device_aid'])
        home_count = self.data.loc[self.data['home'] == 1, ['device_aid', 'loc', 'latitude', 'longitude']].\
            groupby('device_aid').size().to_frame(name='count').reset_index()
        home = pd.merge(home, home_count, on='device_aid', how='left')
        home.to_sql('home', engine, schema='public', index=False,
                    if_exists='append', method='multi', chunksize=5000)

    def find_poi(self, batch=None, radius=300):
        print('Process stops.')
        gdf_stops = workers.df2gdf_point(self.data.loc[self.data['home'] == 0, ['latitude', 'longitude']].
                                         drop_duplicates(subset=['latitude', 'longitude']),
                                         'longitude', 'latitude', crs=4326, drop=False)
        gdf_stops = gdf_stops.to_crs(25832)
        gdf_stops.loc[:, 'y'] = gdf_stops.geometry.y
        gdf_stops.loc[:, 'x'] = gdf_stops.geometry.x
        print(len(gdf_stops))
        gdf_stops.replace([np.inf, -np.inf], np.nan, inplace=True)
        gdf_stops.dropna(subset=["x", "y"], how="any", inplace=True)
        print("After processing infinite values", len(gdf_stops))
        print('Search for nearest POI.')
        ind, dist = self.tree.query_radius(gdf_stops[["y", "x"]].to_records(index=False).tolist(),
                                           r=radius, return_distance=True, count_only=False, sort_results=True)
        gdf_stops.loc[:, 'poi_num'] = [len(x) for x in ind]
        gdf_stops.loc[gdf_stops.poi_num > 0, 'osm_id'] = [self.gdf.loc[x[0], 'osm_id'] for x in ind if len(x) > 0]
        gdf_stops.loc[gdf_stops.poi_num > 0, 'dist'] = [x[0] for x in dist if len(x) > 0]
        gdf_stops = pd.merge(gdf_stops, self.gdf[['osm_id', 'class', 'subclass', 'theme', 'label']],
                             on='osm_id', how='left')
        print('Merge the results back to stops.')
        self.data = pd.merge(self.data,
                             gdf_stops[['latitude', 'longitude', 'osm_id', 'class', 'subclass', 'theme', 'label']],
                             on=['latitude', 'longitude'], how='left')
        self.data = self.data.loc[self.data.home == 0, :].dropna()
        self.data.drop(columns=['home'], inplace=True)
        # self.data.loc[:, 'osm_id'] = self.data.loc[:, 'osm_id'].astype(int)
        # print(self.data.iloc[0])
        self.data.to_parquet(os.path.join(ROOT_dir, f'dbs/stop2poi/stops_poi_{batch}.parquet'), index=False)


if __name__ == '__main__':
    sp = Stops2POIs()
    sp.load_pois()
    for batch in range(0, 300):
        print(f'Process batch {batch}.')
        start = time.time()
        sp.load_stops(batch=batch, test=False)
        sp.home_detection_to_stops(grp_num=20)
        sp.find_poi(batch=batch, radius=300)
        end = time.time()
        time_elapsed = (end - start) // 60  # in minutes
        print(f"Group {batch} processed and saved in {time_elapsed} minutes.")
