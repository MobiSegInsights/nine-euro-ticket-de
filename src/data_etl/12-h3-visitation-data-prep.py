import sys
from pathlib import Path
import os
import pandas as pd
import h3

os.environ['USE_PYGEOS'] = '0'
import time
from tqdm import tqdm
import sqlalchemy

ROOT_dir = Path(__file__).parent.parent.parent
sys.path.append(ROOT_dir)
sys.path.insert(0, os.path.join(ROOT_dir, 'lib'))

import workers

data_folder = os.path.join(ROOT_dir, 'dbs/stop_combined2poi/')
paths2stops = {int(x.split('_')[-1].split('.')[0]): os.path.join(data_folder, x) \
               for x in list(os.walk(data_folder))[0][2]}


class VisitationDayDataPrep:
    def __init__(self):
        self.home = None
        self.user = workers.keys_manager['database']['user']
        self.password = workers.keys_manager['database']['password']
        self.port = workers.keys_manager['database']['port']
        self.db_name = workers.keys_manager['database']['name']

    def load_home(self):
        engine = sqlalchemy.create_engine(
            f'postgresql://{self.user}:{self.password}@localhost:{self.port}/{self.db_name}?gssencmode=disable')
        self.home = pd.read_sql("""SELECT device_aid, latitude, longitude FROM home;""", con=engine)
        self.home.rename(columns={'latitude': 'lat_h', 'longitude': 'lng_h'}, inplace=True)

    def process_bulk(self, batches=None, test=False, res = 8):
        cols = ['device_aid', 'date', 'dur', 'year', 'week', 'weekday',
                'osm_id', 'label', 'latitude', 'longitude']
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
        tqdm.pandas()
        data['h3_id'] = data.progress_apply(lambda row: h3.latlng_to_cell(row['latitude'], row['longitude'],
                                                                     res=res), axis=1)
        data.dropna(inplace=True)
        data.loc[:, 'month'] = data.loc[:, 'date'].apply(lambda x: int(str(x).split('-')[1]))
        data = data.loc[~data['month'].isin([10]), :]

        # Distance calculation
        tqdm.pandas(desc='Distance to home')
        data.loc[:, 'd_h'] = data.progress_apply(lambda row: workers.haversine(row['longitude'], row['latitude'],
                                                                               row['lng_h'], row['lat_h']), axis=1)
        data.drop(columns=['longitude', 'latitude', 'lng_h', 'lat_h'], inplace=True)

        def save_g(group):
            group.to_parquet(os.path.join(ROOT_dir, f'dbs/combined_hex2visits_day/stops_{group.name}.parquet'), index=False)

        data.groupby('batch').apply(save_g, include_groups=False)


if __name__ == '__main__':
    vddp = VisitationDayDataPrep()
    print('Load home records')
    vddp.load_home()
    num = 20
    for i in range(0, 15):
        print(f'Process group {i + 1}/15.')
        start = time.time()
        vddp.process_bulk(batches=[batch for batch in range(i * num, (i + 1) * num)])
        end = time.time()
        time_elapsed = (end - start) / 60  # in minutes
        print(f"Group {i + 1} processed and saved in {time_elapsed} minutes.")

