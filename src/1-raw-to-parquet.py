import sys
from pathlib import Path
import os
import pandas as pd
import utm
import time
from p_tqdm import p_map
from tqdm import tqdm
import numpy as np


ROOT_dir = Path(__file__).parent.parent
sys.path.append(ROOT_dir)
sys.path.insert(0, os.path.join(ROOT_dir, 'lib'))


class DataPrep:
    def __init__(self):
        """
        :param month: 06, 07, 08, 12
        :type month: str
        :return: None
        :rtype: None
        """
        self.raw_data_folder = 'E:\\raw_data_de'  # under the local drive D
        self.converted_data_folder = 'D:\\MAD_dbs\\raw_data_de\\format_parquet'
        self.data = None
        self.devices = None

    def device_grouping(self, num_groups=300):
        devices = []
        for y in (2019, 2022, 2023):
            for m in ('05', '06', '07', '08', '09'):
                print(f'Processing year {y} - month {m}:')
                devices_m = []
                days_list = get_day_list(month=m)
                for day in days_list:
                    df_list = []
                    path = os.path.join(self.raw_data_folder, f'raw_data_de_{y}', m, day)
                    file_list = os.listdir(path)
                    for file in file_list:
                        file_path = os.path.join(path, file)
                        print(f'Loading {file_path}')
                        df_list.append(pd.read_csv(file_path, sep='\t', compression='gzip', usecols=['device_aid']))
                    temp_ = pd.concat(df_list)
                    devices_m += temp_['device_aid'].unique()
                devices_m = np.unique(np.concatenate(devices_m))
                devices.append(devices_m)
        devices = np.unique(np.concatenate(devices_m))
        devices = pd.DataFrame(devices, columns=['device_aid'])
        np.random.seed(68)
        devices.loc[:, 'batch'] = np.random.randint(0, num_groups, size=len(devices))
        devices.to_csv('dbs/devices_grp.csv', index=False)
        self.devices = {x: devices.loc[devices.batch == x, 'uid'].to_list() for x in range(0, num_groups)}

    def process_data(self, selectedcols=None, month=None, year=None, day=None):
        """
        :param selectedcols: a list of column names
        :type selectedcols: list
        :return: None
        :rtype: None
        """
        start = time.time()
        print("Data loading...")
        df_list = []
        path = os.path.join(self.raw_data_folder, f'raw_data_de_{year}', month, day)
        file_list = os.listdir(path)
        for file in file_list:
            file_path = os.path.join(path, file)
            print(f'Loading {file_path}')
            df_list.append(pd.read_csv(file_path, sep='\t', compression='gzip', usecols=selectedcols))
        self.data = pd.concat(df_list)
        np.random.seed(68)
        self.data.loc[:, 'batch'] = np.random.randint(0, 16, size=len(self.data))

        def by_batch(data):
            data.loc[:, "utm_x"] = data.apply(lambda row: utm.from_latlon(row['latitude'], row['longitude'])[0],
                                              axis=1)
            data.loc[:, "utm_y"] = data.apply(lambda row: utm.from_latlon(row['latitude'], row['longitude'])[1],
                                              axis=1)

            return data
        # Process coordinates
        print('Process coordinates...')
        rstl = p_map(by_batch, [g for _, g in self.data.groupby('batch', group_keys=True)])
        self.data = pd.concat(rstl)
        end = time.time()
        print(f"Data processed in {(end - start)/60} minutes.")

    def write_out(self, grp=None, year=None, month=None, day=None):
        dirs = [x[0] for x in os.walk(self.converted_data_folder)]
        target_dir = os.path.join(self.converted_data_folder, 'grp_' + str(grp))
        if target_dir not in dirs:
            os.makedirs(target_dir)
            print("created folder : ", target_dir)

        self.data.drop(columns=['batch']).loc[self.data.device_aid.isin(self.devices[grp]), :]. \
            to_parquet(os.path.join(target_dir, f'{year}_' + month + '_' + day + '.parquet'))

    def dump_to_parquet(self, day=None, year=None, month=None):
        # Save data to database
        start = time.time()
        for grp in tqdm(range(0, len(self.devices)), desc='Saving data'):
            self.write_out(grp=grp, year=year, day=day, month=month)
        end = time.time()
        print(f"Data saved in {(end - start)/60} minutes.")


def get_day_list(month=None):
    days_num = {'05': 31, '06': 30, '07': 31, '08': 31, '09': 30}
    days = ["%02d" % (number,) for number in range(1, days_num[month] + 1)]
    return days


if __name__ == '__main__':
    print('Processing .csv.gz into database by day:')
    data_prep = DataPrep()
    data_prep.device_grouping(num_groups=300)
    days_num = {'05': 31, '06': 30, '07': 31, '08': 31, '09': 30}
    cols = ['timestamp', 'device_aid', 'latitude', 'longitude', 'location_method']
    for y in (2019, 2022, 2023):
        for m in ('05', '06', '07', '08', '09'):
            print(f'Processing year {y} - month {m}:')
            start = time.time()
            days_list = get_day_list(month=m)
            for day in days_list:
                data_prep.process_data(selectedcols=cols, year=y, month=m, day=day)
                data_prep.dump_to_parquet(year=y, month=m, day=day)
            end = time.time()
            time_elapsed = (end - start)//60 #  in minutes
            print(f"Month {m} processed in {time_elapsed} minutes.")
