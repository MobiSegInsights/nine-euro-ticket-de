import sys
from pathlib import Path
import os
import pandas as pd
from p_tqdm import p_map
from tqdm import tqdm
import numpy as np
from multiprocessing import cpu_count
from statsmodels.stats.weightstats import DescrStatsW
import warnings
warnings.filterwarnings("ignore")


ROOT_dir = Path(__file__).parent.parent.parent
sys.path.append(ROOT_dir)
sys.path.insert(0, os.path.join(ROOT_dir, 'lib'))


def ice(ai=None, bi=None, popi=None, share_a=0.25, share_b=0.25):
    oi = popi - ai - bi
    share_o = 1 - share_a - share_b
    return (ai / share_a - bi / share_b) / (ai / share_a + bi / share_b + oi / share_o)


def visit_patterns(data):
    data.loc[:, 'date'] = data.loc[:, 'date'].astype(str)
    metrics_dict = dict()
    # osm_id info
    for var in ('osm_id', 'date', 'year', 'month', 'weekday', 'theme', 'label', 'precipitation', 'pt_station_num'):
        metrics_dict[var] = data[var].values[0]
    # Visits
    metrics_dict['num_visits_wt'] = data['wt_p'].sum()
    metrics_dict['num_unique_device'] = data.device_aid.nunique()
    # Duration
    metrics_dict['dur_total_wt'] = sum(data['dur'] * data['wt_p'])  # min

    # Distance from home
    ## Weighted percentiles
    d, wt = data.loc[data['d_h'] > 0, 'd_h'], data.loc[data['d_h'] > 0, 'wt_p']
    wdf = DescrStatsW(d, weights=wt, ddof=1)
    sts = wdf.quantile([0.25, 0.5, 0.75])
    bds = sts.values
    metrics_dict['d_h25_wt'], metrics_dict['d_h50_wt'], metrics_dict['d_h75_wt'] = bds[0], bds[1], bds[2]

    # Segregation metric
    pop = np.sum(data.wt_p)
    a = np.sum(data.loc[data.grdi_grp == 'H', 'wt_p'])
    b = np.sum(data.loc[data.grdi_grp == 'L', 'wt_p'])
    metrics_dict['ice'] = ice(ai=a, bi=b, popi=pop, share_a=0.25, share_b=0.25)
    metrics_dict['H'], metrics_dict['L'], metrics_dict['M'] = a / pop, b / pop, (pop - a - b) / pop

    ## weighted average
    d_lg = d.apply(lambda x: np.log10(x))
    metrics_dict['d_ha_wt'] = 10 ** np.average(d_lg, weights=wt)
    return pd.Series(metrics_dict)


class VisitsProcessing:
    def __init__(self):
        self.stops_folder = os.path.join(ROOT_dir, 'dbs/poi2visits_day_did/')
        self.paths2stops_list = None
        df_cat = pd.read_excel(os.path.join(ROOT_dir, 'dbs/poi/categories.xlsx')).\
            rename(columns={'category': 'theme', 'subcategory': 'label'})
        self.label_list = df_cat['label'].unique()
        self.osm_ids = None
        self.df = None

    def load_data_and_save(self):
        paths2stops = {int(x.split('_')[-1].split('.')[0]): os.path.join(self.stops_folder, x) \
                       for x in list(os.walk(self.stops_folder))[0][2]}
        self.paths2stops_list = list(paths2stops.values())
        # df_osm = pd.read_parquet('dbs/places_matching/matched_places_wt.parquet')
        df_osm = pd.read_parquet(os.path.join(ROOT_dir, 'dbs/places_matching/places_co_ys.parquet'))
        self.osm_ids = list(df_osm['osm_id'].unique())
        df_t_list = []
        for i in tqdm(self.paths2stops_list):
            tp = pd.read_parquet(i)
            df_t_list.append(tp)
        df_t = pd.concat(df_t_list)
        for lb in tqdm(self.label_list, desc='Writing by label'):
            df_t.loc[df_t.label == lb, :].to_parquet(os.path.join(ROOT_dir, f'dbs/temp/{lb}.parquet'), index=False)

    def label2patterns(self, lb=None, test=False):
        self.df = pd.read_parquet(os.path.join(ROOT_dir, f'dbs/temp/{lb}.parquet'))
        if test:
            self.df = self.df.sample(100000, random_state=42)

        def process_batch(batch):
            return batch.groupby('osm_id').apply(visit_patterns).reset_index(drop=True)

        # Process each batch in parallel using p_map
        df_v_batches = p_map(process_batch,
                             [g for _, g in self.df.groupby('date_time', group_keys=True)],
                             num_cpus=cpu_count())

        # Concatenate all batches into a single DataFrame
        df_v = pd.concat(df_v_batches).reset_index(drop=True)
        print(df_v.head())
        df_v.to_parquet(os.path.join(ROOT_dir, f"dbs/visits_day_did/{lb}.parquet"), index=False)


if __name__ == '__main__':
    vp = VisitsProcessing()
    # vp.load_data_and_save()
    for lb in vp.label_list:
        print(lb)
        vp.label2patterns(lb=lb)
