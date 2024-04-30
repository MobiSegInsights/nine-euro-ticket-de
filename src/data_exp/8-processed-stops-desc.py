import sys
from pathlib import Path
import os
import matplotlib.pyplot as plt
import seaborn as sns
import matplotlib as mpl
import pandas as pd
import time
from tqdm import tqdm
import numpy as np


ROOT_dir = Path(__file__).parent.parent.parent
sys.path.append(ROOT_dir)
sys.path.insert(0, os.path.join(ROOT_dir, 'lib'))

import workers

data_folder = os.path.join(ROOT_dir, 'dbs/stops_p/')
paths2stops = {int(x.split('_')[-1].split('.')[0]): \
                   os.path.join(data_folder, x) for x in list(os.walk(data_folder))[0][2]}


# Individual statistics
def ind_count(data):
    no_loc = data['loc'].nunique()
    no_active_days = data['date'].nunique()
    no_rec = len(data)
    # total_days = np.ceil((data.end.max() - data.start.min()) / 3600 / 24 + 1)
    return pd.Series(dict(no_loc=no_loc, no_active_days=no_active_days, no_rec=no_rec))


def ticks_q(data, var):
    ts = [data[var].min(), np.quantile(data[var], 0.25),
          data[var].median(),
          np.quantile(data[var], 0.75),
          data[var].max()]
    return ts


def one_column_distr(data=None, col=None, col_name=None, xticks=[1, 10, 100, 1000, 2000], filename='stops', type='devices'):
    median_value = data[col].median()
    sns.set(style="ticks")
    f, ax = plt.subplots(figsize=(7, 5))
    sns.despine(f)

    # Create the line plot
    sns.histplot(
        data,
        x=col,
        edgecolor=".3",
        linewidth=.5,
        log_scale=True,
        stat='proportion',
        ax=ax
    )
    ax.axvline(median_value, linestyle='--', label='Median=%.2f' % median_value)
    sns.despine()
    # Enhance the plot
    ax.xaxis.set_major_formatter(mpl.ticker.ScalarFormatter())
    ax.set_xticks(xticks)
    plt.legend(frameon=False)
    plt.xlabel(col_name)
    plt.ylabel(f'Fraction of {type}')
    plt.savefig(os.path.join(ROOT_dir, f'figures/data_desc/{filename}_{col}.png'), dpi=300, format='png')


if __name__ == '__main__':
    batch = 2
    print(f'Process batch {batch}.')
    start = time.time()
    df = pd.read_parquet(paths2stops[batch])
    tqdm.pandas()
    df_ind = df.groupby('device_aid').progress_apply(ind_count).reset_index()
    # Stops - duration in min
    var = 'dur'
    one_column_distr(data=df, col=var,
                     col_name='Duration (min)',
                     xticks=ticks_q(data=df, var=var),
                     filename='stops', type='stops')

    # Individuals - no. of unique locations
    var = 'no_loc'
    one_column_distr(data=df_ind, col=var,
                     col_name='No. of unique locations',
                     xticks=ticks_q(data=df_ind, var=var),
                     filename='stops_indi')

    # Individuals - number of active days
    var = 'no_active_days'
    one_column_distr(data=df_ind, col=var,
                     col_name='No. of active days',
                     xticks=ticks_q(data=df_ind, var=var),
                     filename='stops_indi')

    # Individuals - number of stops
    var = 'no_rec'
    one_column_distr(data=df_ind, col=var,
                     col_name='No. of stops',
                     xticks=ticks_q(data=df_ind, var=var),
                     filename='stops_indi')

    # # Individuals - number of total days
    # var = 'total_days'
    # one_column_distr(data=df_ind, col=var,
    #                  col_name='Time span (day)',
    #                  xticks=ticks_q(data=df_ind, var=var),
    #                  filename='stops_indi')
    end = time.time()
    time_elapsed = (end - start) // 60  # in minutes
    print(f"Group {batch} processed and saved in {time_elapsed} minutes.")