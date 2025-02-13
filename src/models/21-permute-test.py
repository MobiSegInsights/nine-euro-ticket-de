import sys
from pathlib import Path
import os
import pandas as pd
from p_tqdm import p_map
import numpy as np


ROOT_dir = Path(__file__).parent.parent.parent
sys.path.append(ROOT_dir)
sys.path.insert(0, os.path.join(ROOT_dir, 'lib'))

import tdid


# Data paths
data_folder = 'dbs/combined_did_data/'
grp, lv = 'all', 'all'
file1 = data_folder + f'h3_grids_9et_{grp}_{lv}_c.parquet'
file2 = data_folder + f'h3_grids_dt_{grp}_{lv}_c.parquet'


class Permute:
    def __init__(self, tvar=None):
        self.data1 = pd.read_parquet(file1)
        self.data2 = pd.read_parquet(file2)
        self.data = None
        self.tvar = tvar
        self.policy = None
        print(f"Number of unique hexagons for the 9ET: {self.data1['h3_id'].nunique()}")
        print(f"Number of unique hexagons for the DT: {self.data2['h3_id'].nunique()}")

    def data_prep(self, random_seed=None):
        np.random.seed(random_seed)
        if self.policy == 1:
            ylist = [2019, 2022]
            # mlist = [5, 6, 7, 8]
            # ty = np.random.choice(ylist, size=1)
            # cm = np.random.choice(mlist, size=2)
            # tm = [x for x in mlist if x not in cm]
            # self.data = tdid.data_preparation(data=self.data1, year_list=ylist, treatment_yr=ty[0],
            #                                   treatment_months=tm,
            #                                   control_months=list(cm),
            #                                   unit='h3', unit_time='time')
            self.data = tdid.data_preparation(data=self.data1, year_list=ylist, treatment_yr=2022,
                                              treatment_months=[6, 7, 8],
                                              control_months=[9,],
                                              unit='h3', unit_time='time')
        else:
            ylist = [2022, 2023]
            # mlist = [2, 3, 4, 5]
            # ty = np.random.choice(ylist, size=1)
            # cm = np.random.choice(mlist, size=2)
            # tm = [x for x in mlist if x not in cm]
            # self.data = tdid.data_preparation(data=self.data2, year_list=ylist, treatment_yr=ty[0],
            #                                   treatment_months=list(cm),
            #                                   control_months=tm,
            #                                   unit='h3', unit_time='time')
            self.data = tdid.data_preparation(data=self.data2, year_list=ylist, treatment_yr=2023,
                                              treatment_months=[5,],
                                              control_months=[3, 4],
                                              unit='h3', unit_time='time')
        self.data[f"ln_{self.tvar}"] = np.log(self.data[self.tvar])

    def worker(self, random_seed=None):
        self.data_prep(random_seed=random_seed)
        return tdid.perform_stratified_permutation(df=self.data,
                                                   treatment_col='9et',
                                                   post_col='post',
                                                   interaction_col='P_m',
                                                   exog_cols=['P_m', 'rain', 'fuel_price', 'fuel_price_year'],
                                                   absorb_cols=['weekday', 'state_holiday', 'state_month', 'state_year', 'h3'],
                                                   random_seed=random_seed,
                                                   dependent_col=f"ln_{self.tvar}",
                                                   cluster_col='state',
                                                   weights_col=None
                                                   )


if __name__ == '__main__':
    num_permutations = 20
    batch = 25
    df_r_list = []
    for tvar in ('num_visits_wt', 'd_ha_wt'):
        pp = Permute(tvar=tvar)
        policy = 2
        pp.policy = policy
        print('Policy', policy, tvar)
        for i in range(0, batch):
            rstl = p_map(pp.worker, [rs for rs in range(num_permutations*i, num_permutations*(i+1))])
            df_r = pd.DataFrame(rstl, columns=['coefficient', 'pvalue'])
            df_r.loc[:, 'policy'] = policy
            df_r.loc[:, 'var'] = tvar
            df_r_list.append(df_r)
            if i == 0:
                print(df_r)
    df_r = pd.concat(df_r_list)
    df_r.to_csv('results/tdid/permutation_results_by_state_basic_r.csv', index=False)
