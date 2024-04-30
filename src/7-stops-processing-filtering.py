import sys
from pathlib import Path
import os
import pandas as pd
import time
import skmob
from skmob.measures.individual import home_location
from p_tqdm import p_map
from tqdm import tqdm
from datetime import datetime
import numpy as np
import itertools


ROOT_dir = Path(__file__).parent.parent
sys.path.append(ROOT_dir)
sys.path.insert(0, os.path.join(ROOT_dir, 'lib'))

import workers

data_folder = os.path.join(ROOT_dir, 'dbs/stops/')
paths2stops = {int(x.split('_')[-1].split('.')[0]): os.path.join(data_folder, x) for x in list(os.walk(data_folder))[0][2]}


# Individual statistics
def ind_count(data):
    no_loc = data['loc'].nunique()
    no_active_days = data['date'].nunique()
    no_rec = len(data)
    total_days = np.ceil((data.end.max() - data.start.min()) / 3600 / 24 + 1)
    return pd.Series(dict(no_loc=no_loc, no_active_days=no_active_days,
                          no_rec=no_rec, total_days=total_days))


def indi_traj2home(data_input):
    data = data_input[['device_aid', 'latitude', 'longitude', 'loc', 'localtime', 'l_localtime']].copy()
    data.loc[:, 'time_series'] = data.apply(lambda row: pd.date_range(start=row['localtime'],
                                                                      end=row['l_localtime'], freq='15min'), axis=1)
    df_exploded = data[['device_aid', 'latitude', 'longitude', 'time_series']].explode('time_series')
    tdf = skmob.TrajDataFrame(df_exploded, latitude='latitude', longitude='longitude',
                              datetime='time_series', user_id='device_aid')
    hl_df = home_location(tdf, start_night='22:00', end_night='07:00', show_progress=False)
    data = pd.merge(data[['device_aid', 'latitude', 'longitude', 'loc']],
                    hl_df.rename(columns={'uid': 'device_aid', 'lat': 'latitude', 'lng': 'longitude'}),
                  on=['device_aid', 'latitude', 'longitude'], how='inner')
    df_h_stats = data.groupby('device_aid').size().to_frame(name='h_count').reset_index()
    feasible_devices = list(df_h_stats.loc[df_h_stats.h_count >= 3, 'device_aid'].values)
    return feasible_devices


class StopsProcessing:
    def __init__(self):
        self.data = None
        self.data_ind = None

    def load_stops(self, batch=None, test=False):
        self.data = pd.read_parquet(paths2stops[batch])
        if test:
            inds = self.data.device_aid.unique()
            self.data = self.data.loc[self.data.device_aid.isin(inds[:10000]), :]
        print('Domestic filtering.')
        tqdm.pandas()
        self.data.loc[:, 'de'] = self.data.progress_apply(lambda row: workers.within_de_time(row['latitude'],
                                                                                             row['longitude']),
                                                          axis=1)
        len_before = len(self.data)
        self.data = self.data.loc[self.data['de'] == 1]
        len_after = len(self.data)
        self.data.drop(columns='de', inplace=True)
        print(f"Share of stops in Germany: {len_after / len_before * 100} %")

        print('Add time attributes and filter stops beyond (15 min- 12 hour).')
        self.data.loc[:, 'dur'] = (self.data['end'] - self.data['start']) / 60  # min
        tzname = 'Europe/Berlin'
        self.data.loc[:, 'datetime'] = self.data['start'].progress_apply(lambda x: datetime.fromtimestamp(x))
        self.data.loc[:, 'localtime'] = self.data['datetime'].dt.tz_localize('UTC').dt.tz_convert(tzname)
        self.data.loc[:, 'l_datetime'] = self.data['end'].progress_apply(lambda x: datetime.fromtimestamp(x))
        self.data.loc[:, 'l_localtime'] = self.data['l_datetime'].dt.tz_localize('UTC').dt.tz_convert(tzname)
        self.data.loc[:, 'date'] = self.data.loc[:, 'datetime'].dt.date
        len_before = len(self.data)
        self.data = self.data.loc[(self.data['dur'] < 12 * 60) & (self.data['dur'] >= 15)]
        len_after = len(self.data)
        print(f"Share of stops remained: {len_after / len_before * 100} %")

    def filter_individuals(self):
        tqdm.pandas()
        self.data_ind = self.data.groupby('device_aid').progress_apply(ind_count).reset_index()
        # print(self.data_ind.iloc[0])
        len_before = len(self.data_ind)
        self.data_ind = self.data_ind.loc[(self.data_ind['no_loc'] > 2) &\
                                          (self.data_ind['no_rec'] > 3) &\
                                          (self.data_ind['no_active_days'] > 7)]
        len_after = len(self.data_ind)
        print(f"Share of devices remained: {len_after / len_before * 100} %")

        len_before = len(self.data)
        self.data = self.data.loc[self.data['device_aid'].isin(self.data_ind.device_aid.unique())]
        len_after = len(self.data)
        print(f"Share of stops remained: {len_after / len_before * 100} %")

    def home_detection_filtering(self, grp_num=20):
        np.random.seed(68)
        device2group = {x: np.random.randint(1, 21) for x in list(self.data.device_aid.unique())}
        self.data.loc[:, 'home2grp'] = self.data['device_aid'].map(device2group)
        devices2keep = p_map(indi_traj2home, [g for _, g in self.data.groupby('home2grp', group_keys=True)])
        devices2keep = list(itertools.chain(*devices2keep))
        len_before = len(self.data)
        self.data = self.data.loc[self.data['device_aid'].isin(devices2keep)]
        len_after = len(self.data)
        print(f"Share of stops remained for devices with sufficient home records: {len_after / len_before * 100} %")

    def time_enrichment(self):
        """
        This function add a few useful columns based on dataframe's local time.
        :type data: dataframe
        :return: A dataframe with hour of the time, holiday label
        """
        # Add start time hour and duration in minute
        print('Enrich time attributes.')
        self.data.loc[:, 'h_s'] = self.data.loc[:, 'localtime'].dt.hour
        self.data.loc[:, 'year'] = self.data['localtime'].dt.year
        self.data.loc[:, 'weekday'] = self.data.loc[:, 'localtime'].dt.dayofweek
        self.data.loc[:, 'week'] = self.data.loc[:, 'localtime'].dt.isocalendar().week
        self.data.loc[:, 'date'] = self.data.loc[:, 'localtime'].dt.date
        # Add individual sequence index
        print('Enrich individual sequences.')
        self.data = self.data.sort_values(by=['device_aid', 'start'], ascending=True)
        self.data.loc[:, 'seq'] = self.data.groupby('device_aid').cumcount() + 1
        self.data.drop(columns=['interval', 'start', 'end',
                                'datetime', 'l_datetime', 'home2grp'], inplace=True)


if __name__ == '__main__':
    for batch in range(0, 300):
        print(f'Process batch {batch}.')
        start = time.time()
        sp = StopsProcessing()
        sp.load_stops(batch=batch, test=False)
        sp.filter_individuals()
        sp.home_detection_filtering(grp_num=20)
        sp.time_enrichment()
        # print(sp.data.iloc[0])
        sp.data.to_parquet(os.path.join(ROOT_dir, f'dbs/stops_p/stops_p_{batch}.parquet'))
        end = time.time()
        time_elapsed = (end - start) // 60  # in minutes
        print(f"Group {batch} processed and saved in {time_elapsed} minutes.")
