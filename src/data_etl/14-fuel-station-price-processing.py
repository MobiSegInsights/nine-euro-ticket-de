import sys
from pathlib import Path
import os
import pandas as pd
os.environ['USE_PYGEOS'] = '0'
import sqlalchemy
import numpy as np
from sklearn.neighbors import KDTree
from tqdm import tqdm

ROOT_dir = Path(__file__).parent.parent.parent
sys.path.append(ROOT_dir)
sys.path.insert(0, os.path.join(ROOT_dir, 'lib'))

import workers


# Data location
user = workers.keys_manager['database']['user']
password = workers.keys_manager['database']['password']
port = workers.keys_manager['database']['port']
db_name = workers.keys_manager['database']['name']


class FuelPriceProcessing:
    def __init__(self):
        self.gdf_fs = None
        self.gdf_indi = None
        self.ind = None
        self.dist = None

    def load_data(self):
        engine = sqlalchemy.create_engine(
            f'postgresql://{user}:{password}@localhost:{port}/{db_name}?gssencmode=disable')
        print("Load home locations.")
        df_indi = pd.read_sql("""SELECT device_aid, num_unique_poi FROM home_g;""", con=engine)
        df_indi = pd.merge(df_indi,
                           pd.read_sql("""SELECT device_aid, latitude, longitude FROM home;""", con=engine),
                           on='device_aid', how='left')
        self.gdf_indi = workers.df2gdf_point(df_indi, 'latitude', 'longitude', crs=4326, drop=False)
        print('Process home locations.')
        self.gdf_indi = self.gdf_indi.to_crs(25832)
        self.gdf_indi.loc[:, 'y'] = self.gdf_indi.geometry.y
        self.gdf_indi.loc[:, 'x'] = self.gdf_indi.geometry.x
        self.gdf_indi.replace([np.inf, -np.inf], np.nan, inplace=True)
        self.gdf_indi.dropna(subset=["x", "y"], how="any", inplace=True)

        print('Process fuel stations.')
        df_fs = pd.read_csv('dbs/fuel_price/stations.csv')
        self.gdf_fs = workers.df2gdf_point(df_fs[['uuid', 'latitude', 'longitude']], 'latitude', 'longitude', crs=4326,
                                      drop=False)
        self.gdf_fs = self.gdf_fs.to_crs(25832)  # Projection in meter for Germany
        self.gdf_fs.loc[:, 'y'] = self.gdf_fs.geometry.y
        self.gdf_fs.loc[:, 'x'] = self.gdf_fs.geometry.x
        self.gdf_fs = self.gdf_fs.reset_index(drop=True)

    def search_nearby_stations(self, radius=10):
        tree = KDTree(self.gdf_fs[["y", "x"]], metric="euclidean")
        print('Search for nearest stations.')
        radius = radius * 1000  # 80 km radius
        self.ind, self.dist = tree.query_radius(self.gdf_indi[["y", "x"]].to_records(index=False).tolist(),
                                      r=radius, return_distance=True, count_only=False, sort_results=True)
        self.gdf_indi.loc[:, 'station_num'] = [len(x) for x in self.ind]
        print('Share of individuals w/o nearby stations,',
              len(self.gdf_indi.loc[self.gdf_indi['station_num'] == 0, :]) / len(self.gdf_indi))

    def assign_nearby_stations(self):
        def one_individual(x):
            sts = self.gdf_fs.loc[x, ['uuid']]
            sta_list = [str(j) for j in sts.loc[:, 'uuid'].values[:5]]
            return ','.join(sta_list)

        def batch(chunk):
            stations_list = []
            for c in tqdm(chunk):
                stations_list.append(one_individual(c))
            return stations_list

        # Divide the array into 20 chunks
        chunks = np.array_split(self.ind, 5)
        sl0, sl1, sl2, sl3, sl4 = batch(chunks[0]), batch(chunks[1]), batch(chunks[2]), batch(chunks[3]), batch(chunks[4])

        # list_of_st_lists = p_map(batch, chunks)
        #self.gdf_indi.loc[:, 'station_id'] = sum(list_of_st_lists, [])

        self.gdf_indi.loc[:, 'station_id'] = sl0 + sl1 + sl2 + sl3 + sl4
        print("Save data")
        engine = sqlalchemy.create_engine(
            f'postgresql://{user}:{password}@localhost:{port}/{db_name}?gssencmode=disable')
        self.gdf_indi[['device_aid', 'station_num', 'station_id']]. \
            to_sql('fuel_station', con=engine, index=False, method='multi', if_exists='replace', chunksize=5000)


if __name__ == '__main__':
    fpp = FuelPriceProcessing()
    fpp.load_data()
    fpp.search_nearby_stations(radius=10)
    fpp.assign_nearby_stations()
