import sys
from pathlib import Path
import os
import matplotlib.pyplot as plt
import seaborn as sns
import matplotlib.dates as mdates
import pandas as pd


ROOT_dir = Path(__file__).parent.parent.parent
sys.path.append(ROOT_dir)
sys.path.insert(0, os.path.join(ROOT_dir, 'lib'))

import workers

data_folder = 'dbs/visits_day/'
paths2visits = {x.split('.')[0]: os.path.join(data_folder, x) for x in list(os.walk(data_folder))[0][2]}


def time_series_device(data=None, lb=None, yvar='num_unique_device', ylb='Daily device count',
                       filename='daily_device_count'):
    sns.set(style="ticks")
    data_a = data.groupby(['year', 'month'])[yvar].median().reset_index().rename(columns={yvar: 'average'})
    data = pd.merge(data, data_a, on=['year', 'month'], how='left')
    # Create the time series plot
    fig, ax = plt.subplots(nrows=1, ncols=1, figsize=(10, 5))

    # Plotting
    sns.lineplot(x='date_time', y=yvar, data=data, hue='month', ax=ax,
                 style='year', style_order=[2022, 2019, 2023])
    sns.lineplot(x='date_time', y='average', data=data, hue='month', ax=ax,
                 style='year', style_order=[2022, 2019, 2023], legend=None)
    sns.despine()
    ax.xaxis.set_major_formatter(mdates.DateFormatter('%b'))
    # Set common labels
    ax.set(xlabel='Date', ylabel=ylb)
    plt.legend(bbox_to_anchor=(1.04, 1), loc="upper left", frameon=False)
    plt.title(lb)
    plt.tight_layout()  # Adjust layout to not cut off labels
    plt.savefig(os.path.join(ROOT_dir, f'figures/visits_day_desc/{filename}_{lb}.png'),
                dpi=300, format='png')


def time_process(data):
    data.loc[:, 'year'] = data.loc[:, 'date'].apply(lambda x: int(x.split('-')[0]))
    data.loc[:, 'month'] = data.loc[:, 'date'].apply(lambda x: int(x.split('-')[1]))
    data.loc[:, 'date_time'] = pd.to_datetime(data.loc[:, 'date'].apply(lambda x: '-'.join(x.split('-')[1:])),
                                              format='%m-%d')
    return data


if __name__ == '__main__':
    for lb in paths2visits:
        print(f'Process {lb}...')
        df_v = pd.read_parquet(paths2visits[lb])

        # Daily unique device count
        df_v_device = time_process(df_v.groupby('date')['num_unique_device'].sum().reset_index())
        time_series_device(data=df_v_device, lb=lb,
                           yvar='num_unique_device',
                           ylb='Daily device count',
                           filename='daily_device_count')

        # Time spent weighted (million minutes)
        df_v_t = time_process(df_v.groupby('date')['dur_total_wt'].sum().reset_index())
        df_v_t.loc[:, 'dur_total_wt'] /= 10**6
        time_series_device(data=df_v_t, lb=lb,
                           yvar='dur_total_wt',
                           ylb='Total time spent ($10^6$ min)',
                           filename='daily_total_time')

        # Distance from home
        df_v_dh = time_process(df_v.groupby('date')['d_h50'].median().reset_index())
        time_series_device(data=df_v_dh, lb=lb,
                           yvar='d_h50',
                           ylb='Distance from home (km)',
                           filename='distance_from_home')
