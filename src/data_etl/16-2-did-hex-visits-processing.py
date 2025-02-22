import sys
from pathlib import Path
import os
import pandas as pd
import time
from tqdm import tqdm
from p_tqdm import p_map
import numpy as np
import sqlalchemy


ROOT_dir = Path(__file__).parent.parent.parent
sys.path.append(ROOT_dir)
sys.path.insert(0, os.path.join(ROOT_dir, 'lib'))

import workers

data_folder = os.path.join(ROOT_dir, 'dbs/combined_hex2visits_day_did_g/')
hex_file_list = [data_folder + x for x in list(os.walk(data_folder))[0][2]]


def visit_patterns_hex(x):
    data = x.copy()
    # Only consider unique visitors
    # data.drop_duplicates(subset=['device_aid'], inplace=True)
    data.loc[:, 'date'] = data.loc[:, 'date'].astype(str)
    metrics_dict = dict()
    # osm_id info
    for var in ('year', 'month', 'weekday'):
        metrics_dict[var] = data[var].values[0]
    # Spatial characteristics
    for var in ('precipitation', 'pt_station_num'):
        metrics_dict[var] = np.average(data[var], weights=data['wt_p'])
    # Visits
    metrics_dict['num_visits_wt'] = data['wt_p'].sum()
    metrics_dict['num_unique_device'] = data.device_aid.nunique()

    # Individuals in the origins
    if len(data.loc[~data['f_share'].isna(), :]) > 0:
        metrics_dict['f_share'] = np.average(data.loc[~data['f_share'].isna(), 'f_share'],
                                             weights=data.loc[~data['f_share'].isna(), 'wt_p'])
    else:
        metrics_dict['f_share'] = np.nan

    if len(data.loc[~data['net_rent_100m'].isna(), :]) > 0:
        metrics_dict['net_rent_100m'] = np.average(data.loc[~data['net_rent_100m'].isna(), 'net_rent_100m'],
                                          weights=data.loc[~data['net_rent_100m'].isna(), 'wt_p'])
    else:
        metrics_dict['net_rent_100m'] = np.nan

    if len(data.loc[~data['ef'].isna(), :]) > 0:
        metrics_dict['fuel_price'] = np.average(data.loc[~data['ef'].isna(), 'ef'],
                                          weights=data.loc[~data['ef'].isna(), 'wt_p'])
    else:
        metrics_dict['fuel_price'] = np.nan

    ## weighted average
    d, wt = data.loc[data['d_h'] > 0, 'd_h'], data.loc[data['d_h'] > 0, 'wt_p']
    d_lg = d.apply(lambda x: np.log10(x))
    metrics_dict['d_ha_wt'] = 10 ** np.average(d_lg, weights=wt)
    return pd.Series(metrics_dict)  # pd.DataFrame(metrics_dict, index=[0])


class VisitationCompute:
    def __init__(self):
        self.data = None
        self.data_ind = None
        self.ind_urban_list = None
        self.user = workers.keys_manager['database']['user']
        self.password = workers.keys_manager['database']['password']
        self.port = workers.keys_manager['database']['port']
        self.db_name = workers.keys_manager['database']['name']

    def load_indi(self):
        engine = sqlalchemy.create_engine(
            f'postgresql://{self.user}:{self.password}@localhost:{self.port}/{self.db_name}?gssencmode=disable')
        self.data_ind = pd.read_sql("""SELECT * FROM device_grp;""", con=engine)
        df_ur = pd.read_sql("""SELECT * FROM device_grp_pd;""", con=engine)
        # Use 1000 as the threshold to define the urban residents
        self.ind_urban_list = df_ur.loc[df_ur['pop_density_10km'] >= 1000, 'device_aid'].values

    def visits(self, file=None, urban=False, all=True):
        self.data = pd.read_parquet(file)
        self.data = pd.merge(self.data, self.data_ind.drop(columns=['wt_p']), on='device_aid', how='left')
        if not all:
            if urban:
                self.data = self.data.loc[self.data['device_aid'].isin(self.ind_urban_list), :]
            else:
                self.data = self.data.loc[~self.data['device_aid'].isin(self.ind_urban_list), :]
        print("No. of devices covered: ", self.data['device_aid'].nunique())

    def group_agg_visits(self, v=None):
        combi = self.data[['h3_id', 'date', v]].drop_duplicates()
        num_groups = 20
        np.random.seed(68)
        combi.loc[:, 'batch'] = np.random.randint(0, num_groups, size=len(combi))

        self.data = pd.merge(self.data, combi, on=['h3_id', 'date', v], how='left')

        def by_batch(data):
            return data.groupby(['h3_id', 'date', v]).apply(visit_patterns_hex).reset_index()

        rstl = p_map(by_batch, [g for _, g in self.data.groupby('batch', group_keys=True)])
        df_v = pd.concat(rstl)
        del rstl
        df_v.rename(columns={v: 'level'}, inplace=True)
        df_v.loc[:, 'group'] = v
        self.data.drop(columns=['batch'], inplace=True)
        return df_v


if __name__ == '__main__':
    vc = VisitationCompute()
    print('Load individual attributes.')
    vc.load_indi()
    # Specify the covered devices
    all, urban = False, False
    if all:
        target_folder = 'dbs/combined_visits_day_did_hex_r/'
    else:
        if urban:
            target_folder = 'dbs/combined_visits_day_did_hex_r_urban/'
        else:
            target_folder = 'dbs/combined_visits_day_did_hex_r_nurban/'
    print(f'Start processing to {target_folder}.')

    for f, i in zip(hex_file_list, range(1, len(hex_file_list) + 1)):
        name = f.split('/')[-1]
        finished_folder = os.path.join(ROOT_dir, target_folder)
        finished_list = [finished_folder + x for x in list(os.walk(finished_folder))[0][2]]
        finished_list = [x.split('/')[-1] for x in finished_list]
        if name not in finished_list:
            start = time.time()
            print(f'File {i}/{len(hex_file_list)}...')
            vc.visits(file=f, all=all, urban=urban)
            tqdm.pandas()
            combi = vc.data[['h3_id', 'date']].drop_duplicates()
            num_groups = 20
            np.random.seed(68)
            combi.loc[:, 'batch'] = np.random.randint(0, num_groups, size=len(combi))

            vc.data = pd.merge(vc.data, combi, on=['h3_id', 'date'], how='left')

            def by_batch_all(data):
                return data.groupby(['h3_id', 'date']).apply(visit_patterns_hex).reset_index()


            rstl = p_map(by_batch_all, [g for _, g in vc.data.groupby('batch', group_keys=True)])
            df_v = pd.concat(rstl)
            vc.data.drop(columns=['batch'], inplace=True)
            df_v.loc[:, 'group'] = 'all'
            df_v.loc[:, 'level'] = 'all'
            df_v.to_parquet(os.path.join(ROOT_dir, target_folder + f'{name}'))
            del df_v
            end = time.time()
            time_elapsed = (end - start) // 60  # in minutes
            print(f"Group {i} processed and saved in {time_elapsed} minutes.")
        else:
            print(f'File {i}/{len(hex_file_list)} finished.')
