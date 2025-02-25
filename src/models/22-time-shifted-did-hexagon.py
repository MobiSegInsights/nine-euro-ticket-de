import sys
from pathlib import Path
import os
import pandas as pd
import sqlalchemy
import numpy as np
import pickle


ROOT_dir = Path(__file__).parent.parent.parent
sys.path.append(ROOT_dir)
sys.path.insert(0, os.path.join(ROOT_dir, 'lib'))

import tdid
import workers


def percent_convert(x):
    pc = (np.exp(x) - 1) * 100
    return pc


# Data paths
data_folder = 'dbs/combined_did_data_dt/'
target_file = 'results/tdid/model_results_dt.csv'   # 'results/tdid/model_results_re_nurban.csv'
grp, lv = 'all', 'all'
file2 = data_folder + f'h3_grids_dt_{grp}_{lv}.parquet'
cluster_name = {'Balanced mix': 'q3', 'Low-activity area': 'q1',
                'High-activity hub': 'q4', 'Recreational area': 'q2'}


class TimeShiftedDiD:
    def __init__(self, tvar=None):
        self.user = workers.keys_manager['database']['user']
        self.password = workers.keys_manager['database']['password']
        self.port = workers.keys_manager['database']['port']
        self.db_name = workers.keys_manager['database']['name']
        self.data2 = pd.read_parquet(file2)
        self.data = None
        self.tvar = tvar
        print(f"Number of unique hexagons for the DT: {self.data2['h3_id'].nunique()}")
        print(len(self.data2))

    def add_poi_grps(self):
        engine = sqlalchemy.create_engine(
            f'postgresql://{self.user}:{self.password}@localhost:{self.port}/{self.db_name}?gssencmode=disable')
        # Clustering groups
        df_poi = pd.read_sql("""SELECT * FROM h3_poi_cluster_grp;""", con=engine)
        self.data2 = pd.merge(self.data2, df_poi[['h3_id', 'cluster_name']], on='h3_id', how='left')
        self.data2.loc[:, 'cluster'] = self.data2.loc[:, 'cluster_name'].map(cluster_name)

    def bivariate_group(self):
        h3_id_list = list(set(list(self.data2['h3_id'].unique())))
        # Load from the pickle file
        with open(data_folder + 'fr_groups.pkl', 'rb') as f:
            fr_grp_dict = pickle.load(f)

        # Get the new group
        for k, v in fr_grp_dict.items():
            self.data2.loc[:, f'fr_grp_v_{k}'] = self.data2['h3_id'].map(v)

    def data_prep(self, grp=None, weekday=None):
        if weekday is not None:
            wkd = weekday
        else:
            wkd = list(range(0, 7))
        data2use2 = self.data2.loc[self.data2.weekday.isin(wkd), :].copy()
        ylist = [2022, 2023]
        self.data = tdid.data_preparation(data=data2use2, year_list=ylist, treatment_yr=2023, grp=grp,
                                          treatment_months=[5, ],
                                          control_months=[3, 4],
                                          unit='h3', unit_time='time')
        self.data[f"ln_{self.tvar}"] = np.log(self.data[self.tvar])

    def time_did(self, grp=None, weekday=None):
        self.data_prep(grp=grp, weekday=weekday)
        sum_et_v, res = tdid.time_shifted_did_absorbing(df=self.data, target_var=f"ln_{self.tvar}",
                                                        weight=False, time_effect='jue', grp=grp)
        res.loc[:, 'policy'] = 'dt'
        res.loc[:, 'var'] = self.tvar
        df_ci = sum_et_v.conf_int()
        df_ci.index.name = 'variable'
        df_ci.reset_index(inplace=True)
        res = pd.merge(res, df_ci, on='variable', how='left')
        res['r2'] = sum_et_v.rsquared
        for var in ['coefficient', 'std_error', 'upper', 'lower']:
            res[var] = res[var].apply(lambda x: percent_convert(x))
        return res


if __name__ == '__main__':
    df_r_list = []
    main_res, group_res = True, False
    for tvar in ('num_visits_wt', 'd_ha_wt'):
        tsd = TimeShiftedDiD(tvar=tvar)
        # The below poi cluster was done
        if group_res:
            tsd.add_poi_grps()
            tsd.bivariate_group()
        policy = 'dt'
        if main_res:
            # Main effect
            print('Policy', policy, tvar, 'all')
            rstl = tsd.time_did(weekday=None)
            rstl.loc[:, 'grp'] = 'all'
            print(rstl)
            df_r_list.append(rstl)
            # Weekday effect
            print('Policy', policy, tvar, 'all', 'weekday')
            rstl = tsd.time_did(weekday=[0, 1, 2, 3, 4])
            rstl.loc[:, 'grp'] = 'all_weekday'
            print(rstl)
            df_r_list.append(rstl)
            # Weekday effect
            print('Policy', policy, tvar, 'all', 'weekend')
            rstl = tsd.time_did(weekday=[5, 6])
            rstl.loc[:, 'grp'] = 'all_weekend'
            print(rstl)
            df_r_list.append(rstl)
        # Heterogeneity effect
        # Done ['pt_grp', 'f_grp', 'r_grp', 'f_grp_v', 'r_grp_v', 'cluster']
        if group_res:
            for grp in tdid.h_groups_ex_2:
                print('Policy', policy, tvar, grp)
                rstl = tsd.time_did(grp=grp, weekday=None)
                rstl.loc[:, 'grp'] = grp
                print(rstl)
                df_r_list.append(rstl)
    df_r = pd.concat(df_r_list)
    df_r.to_csv(target_file, index=False)
