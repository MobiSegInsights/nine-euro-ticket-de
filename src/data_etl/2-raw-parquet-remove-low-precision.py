import sys
from pathlib import Path
import os
import pandas as pd
from p_tqdm import p_map
import numpy as np

ROOT_dir = Path(__file__).parent.parent.parent
sys.path.append(ROOT_dir)
sys.path.insert(0, os.path.join(ROOT_dir, 'lib'))

data_folder = 'D:\\MAD_dbs\\raw_data_de\\format_parquet_b'
paths = [x[0] for x in os.walk(data_folder)]
paths = paths[1:]


def num_check(x):
    prec = str(x).split('.')[-1]
    if len(prec) <= 2:
        return 1
    else:
        p = int(str(x * 100).split('.')[-1])
        if p == 0:
            return 1
        else:
            return 0


def low_precision_check(x, y):
    try:
        if (num_check(x) == 1) & (num_check(y) == 1):
            return 1
        else:
            return 0
    except:
        return 1


class DataFiltering:
    def __init__(self):
        self.paths2raw = {int(x.split('_')[-1]): x for x in paths}
        self.target_folder = 'D:\\MAD_dbs\\raw_data_de\\format_parquet_br'
        self.target_folder_stats = 'D:\\MAD_dbs\\raw_data_de\\format_parquet_br_stats'

    def low_precision_remove(self, para_set=None):
        batch, file = para_set
        file_path = os.path.join(self.paths2raw[batch], file)
        df = pd.read_parquet(file_path)
        L = len(df)
        df.loc[:, 'low_precision'] = df.apply(lambda row: low_precision_check(row['latitude'], row['longitude']),
                                              axis=1)
        df = df.loc[df.low_precision != 1].drop(columns='low_precision')
        low_share = 1 - len(df) / L
        target_dir = os.path.join(self.target_folder, 'grp_' + str(batch))
        df.to_parquet(target_dir + f'\\{file}', index=False)
        return low_share

    def batch_run(self, batch):
        print(f'Process batch {batch}...')
        files = [x[2] for x in os.walk(self.paths2raw[batch])]
        files = files[0]
        low_share_list = p_map(self.low_precision_remove, [(batch, f) for f in files])
        ls_mean = np.mean(low_share_list)
        print('Save low share stats', '%.2f' % ls_mean)
        data = [files, low_share_list]
        df_stats = pd.DataFrame(list(map(list, zip(*data))), columns=['file', 'low_prec_share'])
        df_stats.loc[:, 'grp'] = batch
        df_stats.to_parquet(self.target_folder_stats + f'\\low_prec_share_{batch}.parquet', index=False)


if __name__ == '__main__':
    dF = DataFiltering()
    # 0-16 are done
    for batch in range(0, 300):    #  range(17, 300):
        dirs = [x[0] for x in os.walk(dF.target_folder)]
        target_dir = os.path.join(dF.target_folder, 'grp_' + str(batch))
        if target_dir not in dirs:
            os.makedirs(target_dir)
        dF.batch_run(batch=batch)
