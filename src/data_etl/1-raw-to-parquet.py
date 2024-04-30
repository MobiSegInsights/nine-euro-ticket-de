import sys
from pathlib import Path
import os
import pandas as pd
import utm
import time
from p_tqdm import p_map, p_umap
from tqdm import tqdm
import numpy as np


ROOT_dir = Path(__file__).parent.parent.parent
sys.path.append(ROOT_dir)
sys.path.insert(0, os.path.join(ROOT_dir, 'lib'))


def by_batch(data):
    def utm_converter(row):
        try:
            res = utm.from_latlon(row['latitude'], row['longitude'])
            return [res[0], res[1]]
        except:
            return [np.nan, np.nan]
    data[['utm_x', 'utm_y']] = data.apply(utm_converter, axis=1, result_type ='expand')
    return data


class DataPrep:
    def __init__(self):
        """
        :return: None
        :rtype: None
        """
        self.raw_data_folder = 'E:\\raw_data_de'  # under the local drive D
        self.converted_data_folder = 'D:\\MAD_dbs\\raw_data_de\\format_parquet'
        self.data = None
        self.devices = None

    def device_logging(self, year=None, month=None):
        devices_m = []
        days_list = get_day_list(month=month)
        # Due to an accident, this date is lost
        if (month == '05') & (year == 2019):
            days_list.remove('14')
        for day in days_list:
            df_list = []
            path = os.path.join(self.raw_data_folder, f'raw_data_de_{y}', m, day)
            file_list = os.listdir(path)
            for file in file_list:
                file_path = os.path.join(path, file)
                print(f'Loading {file_path}')
                df_list.append(pd.read_csv(file_path, sep='\t', compression='gzip', usecols=['device_aid']))
            temp_ = pd.concat(df_list)
            temp_ = temp_[temp_.device_aid.apply(lambda x: isinstance(x, str))]
            devices_m.append(temp_['device_aid'].unique())
            del temp_
        devices_m = np.unique(np.concatenate(devices_m))
        devices_m = pd.DataFrame(devices_m, columns=['uid'])
        devices_m.to_parquet(f'dbs/devices/devices_{year}_{month}.parquet', index=False)

    def device_grouping(self, num_groups=300):
        file_path = os.path.join(ROOT_dir, 'dbs/devices/devices_grp.parquet')
        if os.path.isfile(file_path):
            print('Loading existing groups...')
            self.devices = pd.read_parquet(file_path) # uid, batch = group
            self.devices.rename(columns={'uid': 'device_aid', 'batch': 'grp'}, inplace=True)
            # self.devices.rename(columns={'batch': 'grp'}, inplace=True)
            # self.devices = {x: devices.loc[devices.batch == x, 'uid'].to_list() for x in range(0, num_groups)}
        else:
            print('Grouping users...')
            devices = []
            for year in (2019, 2022, 2023):
                year_df_list = []
                for month in ('05', '06', '07', '08', '09'):
                    print(f'Processing {year} - {month}...')
                    year_df_list.append(pd.read_parquet(os.path.join(ROOT_dir, f'dbs/devices/devices_{year}_{month}.parquet')))
                df_year = pd.concat(year_df_list)
                del year_df_list
                df_year.drop_duplicates(subset=['uid'], inplace=True)
                devices.append(df_year)
                del df_year
            devices = pd.concat(devices)
            devices.drop_duplicates(subset=['uid'], inplace=True)
            np.random.seed(68)
            devices.loc[:, 'batch'] = np.random.randint(0, num_groups, size=len(devices))
            devices.to_parquet(file_path, index=False)
            self.devices = {x: devices.loc[devices.batch == x, 'uid'].to_list() for x in range(0, num_groups)}

    def process_data(self, selectedcols=None, month=None, year=None, day=None):
        """
        :param selectedcols: a list of column names
        :type selectedcols: list
        """
        start = time.time()
        print("Data loading...")
        path = os.path.join(self.raw_data_folder, f'raw_data_de_{year}', month, day)
        file_list = os.listdir(path)
        n = int(len(file_list) / 2)
        file_list_tuple = (file_list[:n], file_list[n:])
        self.data = []
        for file_list in file_list_tuple:
            df_list = []
            for file in file_list:
                file_path = os.path.join(path, file)
                print(f'Loading {file_path}')
                df_list.append(pd.read_csv(file_path, sep='\t', compression='gzip', usecols=selectedcols))
            temp_ = pd.concat(df_list)
            del df_list
            np.random.seed(68)
            temp_.loc[:, 'batch'] = np.random.randint(0, 16, size=len(temp_))
            # Process coordinates
            print('Process coordinates...')
            rstl = p_map(by_batch, [g for _, g in temp_.groupby('batch', group_keys=True)])
            temp_ = pd.concat(rstl)
            del rstl
            temp_.drop(columns=['batch'], inplace=True)
            print('Adding group id to device_aids...')
            temp_ = pd.merge(temp_, self.devices[['device_aid', 'grp']],
                             on='device_aid', how='left')
            self.data.append(temp_)
            del temp_
        end = time.time()
        print(f"Data processed in {(end - start)/60} minutes.")

    def write_out(self, year=None, month=None, day=None):
        dirs = [x[0] for x in os.walk(self.converted_data_folder)]

        def write_data(data=None, hf=None):
            grp = data.name
            target_dir = os.path.join(self.converted_data_folder, 'grp_' + str(grp))
            if target_dir not in dirs:
                os.makedirs(target_dir)
                print("created folder : ", target_dir)
            data.to_parquet(os.path.join(target_dir, f'{year}_' + month + '_' + day + f'_{hf}.parquet'))

        for d, hf in zip(self.data, (1, 2)):
            print(f'Saving half {hf}')
            tqdm.pandas()
            d.groupby('grp').progress_apply(lambda x: write_data(data=x, hf=hf))

    def dump_to_parquet(self, day=None, year=None, month=None):
        # Save data to database
        start = time.time()
        print('Saving data...')
        for grp in tqdm(range(0, len(self.devices)), desc='Saving data'):
            self.write_out(grp=grp, year=year, day=day, month=month)
        self.data = None
        end = time.time()
        print(f"Data saved in {(end - start)/60} minutes.")

    def reprocess_single_data_file(self, selectedcols=None, month=None, year=None, day=None, grp=None):
        """
        :param selectedcols: a list of column names
        :type selectedcols: list
        """

        target_dir = os.path.join(self.converted_data_folder, 'grp_' + str(grp))

        start = time.time()
        print("Data loading...")
        path = os.path.join(self.raw_data_folder, f'raw_data_de_{year}', month, day)
        file_list = os.listdir(path)
        n = int(len(file_list) / 2)
        file_list_tuple = (file_list[:n], file_list[n:])
        for file_list, hf in zip(file_list_tuple, range(1, 3)):
            print(f"Half {hf} is being processed.")
            df_list = []
            for file in file_list:
                file_path = os.path.join(path, file)
                print(f'Loading {file_path}')
                df_list.append(pd.read_csv(file_path, sep='\t', compression='gzip', usecols=selectedcols))
            temp_ = pd.concat(df_list)
            del df_list

            print('Adding group id to device_aids...')
            temp_ = pd.merge(temp_, self.devices[['device_aid', 'grp']],
                             on='device_aid', how='left')
            temp_ = temp_.loc[temp_['grp'] == grp, :]
            temp_.loc[:, 'grp'] = temp_.loc[:, 'grp'].astype(int)

            # Process coordinates
            print('Process coordinates...')
            np.random.seed(68)
            temp_.loc[:, 'batch'] = np.random.randint(0, 16, size=len(temp_))
            rstl = p_map(by_batch, [g for _, g in temp_.groupby('batch', group_keys=True)])
            temp_ = pd.concat(rstl)
            del rstl
            temp_.drop(columns=['batch'], inplace=True)

            # Write out
            temp_.to_parquet(os.path.join(target_dir, f'{year}_' + month + '_' + day + f'_{hf}.parquet'))

        end = time.time()
        print(f"Data processed in {(end - start)/60} minutes.")

    def reprocess_single_day(self, selectedcols=None, month=None, year=None, day=None):
        """
        :param selectedcols: a list of column names
        :type selectedcols: list
        """
        start = time.time()
        print("Data loading...")
        path = os.path.join(self.raw_data_folder, f'raw_data_de_{year}', month, day)
        file_list = os.listdir(path)
        n = int(len(file_list) / 2)
        file_list_tuple = (file_list[:n], file_list[n:])
        for file_list, hf in zip(file_list_tuple, range(1, 3)):
            print(f"Half {hf} is being processed.")
            df_list = []
            for file in file_list:
                file_path = os.path.join(path, file)
                print(f'Loading {file_path}')
                df_list.append(pd.read_csv(file_path, sep='\t', compression='gzip', usecols=selectedcols))
            temp_ = pd.concat(df_list)
            del df_list

            print('Adding group id to device_aids...')
            temp_ = pd.merge(temp_, self.devices[['device_aid', 'grp']],
                             on='device_aid', how='left')
            temp_.loc[:, 'grp'] = temp_.loc[:, 'grp'].astype(int)

            # Process coordinates
            print('Process coordinates...')
            np.random.seed(68)
            temp_.loc[:, 'batch'] = np.random.randint(0, 16, size=len(temp_))
            rstl = p_map(by_batch, [g for _, g in temp_.groupby('batch', group_keys=True)])
            temp_ = pd.concat(rstl)
            del rstl
            temp_.drop(columns=['batch'], inplace=True)
            self.data = temp_
            del temp_
            # Write out
            self.write_out(year=year, month=month, day=day)
        end = time.time()
        print(f"Data processed in {(end - start)/60} minutes.")


def get_day_list(month=None):
    days_num = {'05': 31, '06': 30, '07': 31, '08': 31, '09': 30}
    days = ["%02d" % (number,) for number in range(1, days_num[month] + 1)]
    return days


if __name__ == '__main__':
    # Stage 1- Logging device ids
    # Stage 2- Processing files
    # Stage 3- Fix problematic day-groups
    # Stage 4- Fix single day for multiple groups
    stage = 3
    if stage == 1:
        print('Processing .csv.gz to log all device ids:')
        data_prep = DataPrep()
        days_num = {'05': 31, '06': 30, '07': 31, '08': 31, '09': 30}
        cols = ['timestamp', 'device_aid', 'latitude', 'longitude', 'location_method']
        for y in (2022, 2023):  # 2019,
            for m in ('05', '06', '07', '08', '09'):
                if ((y == 2022) & (m == '09')) | (y == 2023):
                    print(f'Processing year {y} - month {m}:')
                    data_prep.device_logging(year=y, month=m)

    if stage == 2:
        print('Processing .csv.gz into parquet by day:')
        days_num = {'05': 31, '06': 30, '07': 31, '08': 31, '09': 30}
        cols = ['timestamp', 'device_aid', 'latitude', 'longitude', 'location_method']
        data_prep = DataPrep()
        print('Prepare batches...')
        data_prep.device_grouping(num_groups=300)
        # To start with (2019, '06', '25')
        trackers = [(x, y) for x in (2019, 2022, 2023) for y in ('05', '06', '07', '08', '09')]
        for item in [(2019, '05'), (2019, '06'), (2019, '07')]:
            trackers.remove(item)
        for y, m in trackers:
            print(f'Processing year {y} - month {m}:')
            start = time.time()
            days_list = get_day_list(month=m)
            if (m == '08') & (y == 2019):
                del days_list[:17]
            for day in days_list:
                data_prep.process_data(selectedcols=cols, year=y, month=m, day=day)
                data_prep.write_out(year=y, month=m, day=day)
                # data_prep.dump_to_parquet(year=y, month=m, day=day)
            end = time.time()
            time_elapsed = (end - start)//60    #  in minutes
            print(f"Month {m} processed in {time_elapsed} minutes.")

    if stage == 3:
        cols = ['timestamp', 'device_aid', 'latitude', 'longitude', 'location_method']
        data_prep = DataPrep()
        data_prep.device_grouping(num_groups=300)
        for grp in range(139, 149):
            print(f'Checking batch {grp}....')
            folder = f'D:/MAD_dbs/raw_data_de/format_parquet/grp_{grp}/'
            prob_files = []
            for filename in tqdm(os.listdir(folder), desc='Going through files'):
                file_path = os.path.join(folder, filename)
                try:
                    df = pd.read_parquet(file_path, engine='fastparquet')
                except:
                    prob_files.append(file_path)

            print(f'Identified {len(prob_files)} corrupted files to be fixed.')
            for f in prob_files:
                rec = prob_files[0].split('/')[-1].split('_')
                y, m, day = int(rec[0]), rec[1], rec[2]
                data_prep.reprocess_single_data_file(selectedcols=cols, month=m, year=y, day=day, grp=grp)

    if stage == 4:
        cols = ['timestamp', 'device_aid', 'latitude', 'longitude', 'location_method']
        data_prep = DataPrep()
        data_prep.device_grouping(num_groups=300)
        y, m, day = 2019, '09', '19'
        data_prep.reprocess_single_day(selectedcols=cols, month=m, year=y, day=day)
