import os
from pathlib import Path
import yaml
import pandas as pd
from geoalchemy2 import Geometry, WKTElement
from pathlib import Path
import numpy as np
from datetime import datetime
import sqlalchemy
import time
from tqdm import tqdm
from p_tqdm import p_map
import multiprocessing
from geopandas import GeoDataFrame
from shapely.geometry import Point
from math import radians, cos, sin, asin, sqrt
from timezonefinder import TimezoneFinder


ROOT_dir = Path(__file__).parent.parent
with open(os.path.join(ROOT_dir, 'dbs', 'keys.yaml')) as f:
    keys_manager = yaml.load(f, Loader=yaml.FullLoader)


de_box = (5.98865807458, 47.3024876979, 15.0169958839, 54.983104153)


def get_timezone(longitude, latitude):
    if longitude is None or latitude is None:
        return None
    tzf = TimezoneFinder()
    try:
        timeZone = tzf.timezone_at(lng=longitude, lat=latitude)
    except:
        timeZone = None
    return timeZone


def within_de_time(latitude, longitude):
    if (latitude >= de_box[1]) & (latitude <= de_box[3]):
        if (longitude >= de_box[0]) & (longitude <= de_box[2]):
            return 1
    return 0


class TimeProcessing:
    def __init__(self, data=None):
        # device_aid, timestamp, latitude, longitude
        self.data = data

    def time_processing(self):
        tqdm.pandas()
        self.data.loc[:, 'datetime'] = self.data['timestamp'].progress_apply(lambda x: datetime.fromtimestamp(x))
        self.data.loc[:, 'de_time'] = self.data.\
            progress_apply(lambda row: within_de_time(row['latitude'], row['longitude']), axis=1)
        print("Share of data in Germany time: %.2f %%" % (self.data.loc[:, 'de_time'].sum() / len(self.data) * 100))

    def time_zone_parallel(self):
        df_sub = self.data.loc[self.data.de_time == 0, :].copy()
        df_de = self.data.loc[self.data.de_time == 1, :].copy()
        df_de.loc[:, 'tzname'] = 'Europe/Berlin'

        def find_time_zone(data):
            data.loc[:, 'tzname'] = data.apply(lambda row: get_timezone(row['longitude'], row['latitude']), axis=1)
            return data

        df_sub.loc[:, 'batch'] = np.random.randint(1, 101, df_sub.shape[0])
        rstl = p_map(find_time_zone, [g for _, g in df_sub.groupby('batch', group_keys=True)])
        df_sub = pd.concat(rstl)
        L_before = len(df_sub)
        df_sub = df_sub[df_sub.tzname.notna()]
        L_after = len(df_sub)
        print("Share of data remained after removing unknown timezone: %.2f %%" % (L_after / L_before * 100))
        self.data = pd.concat([df_de, df_sub.drop(columns=['batch'])])
        self.data = self.data.drop(columns=['de_time'])

    def convert_to_local_time(self):
        def zone_grp(k, data):
            data.loc[:, "localtime"] = data['datetime'].dt.tz_localize('UTC').dt.tz_convert(k)
            return data
        mk = int(len(self.data)/2)
        part1 = self.data.iloc[:mk, :]
        part2 = self.data.iloc[mk:, :]
        print('Convert to local time: part 1.')
        rstl1 = p_map(zone_grp,
                     [k for k, _ in part1.groupby('tzname', group_keys=True)],
                     [g for _, g in part1.groupby('tzname', group_keys=True)])
        print('Convert to local time: part 2.')
        rstl2 = p_map(zone_grp,
                     [k for k, _ in part2.groupby('tzname', group_keys=True)],
                     [g for _, g in part2.groupby('tzname', group_keys=True)])
        self.data = pd.concat(rstl1 + rstl2)
        # print(self.data.iloc[0])

    def time_enrich(self):
        # Add start time hour and duration in minute
        self.data['localtime'] = pd.to_datetime(self.data['localtime'], errors='coerce')
        self.data.loc[:, 'hour'] = self.data.loc[:, 'localtime'].dt.hour
        self.data.loc[:, 'weekday'] = self.data.loc[:, 'localtime'].dt.dayofweek
        self.data.loc[:, 'week'] = self.data.loc[:, 'localtime'].dt.isocalendar().week
        self.data.loc[:, 'date'] = self.data.loc[:, 'localtime'].dt.date
        # Add individual sequence index
        self.data = self.data.sort_values(by=['device_aid', 'timestamp'], ascending=True)

        def indi_seq(df):
            df.loc[:, 'seq'] = range(1, len(df) + 1)
            return df

        reslt = p_map(indi_seq, [g for _, g in self.data.groupby('device_aid', group_keys=True)])
        self.data = pd.concat(reslt)


class TimeProcessingStops:
    def __init__(self, data=None):
        # device_aid, start, end, latitude, longitude
        self.data = data

    def time_processing(self):
        self.data.loc[:, 'dur'] = (self.data.loc[:, 'end'] - self.data.loc[:, 'start']) / 60    # min
        print('Convert to datetime.')
        tqdm.pandas()
        self.data.loc[:, 'datetime'] = self.data['start'].progress_apply(lambda x: datetime.fromtimestamp(x))
        self.data.loc[:, 'leaving_datetime'] = self.data['end'].progress_apply(lambda x: datetime.fromtimestamp(x))
        self.data.loc[:, 'de_time'] = self.data.\
            progress_apply(lambda row: within_de_time(row['latitude'], row['longitude']), axis=1)
        print("Share of data in Germany time: %.2f %%" % (self.data.loc[:, 'de_time'].sum() / len(self.data) * 100))

    def time_zone_parallel(self):
        df_sub = self.data.loc[self.data.de_time == 0, :].copy()
        df_de = self.data.loc[self.data.de_time == 1, :].copy()
        df_de.loc[:, 'tzname'] = 'Europe/Berlin'

        def find_time_zone(data):
            data.loc[:, 'tzname'] = data.apply(lambda row: get_timezone(row['longitude'], row['latitude']), axis=1)
            return data

        df_sub.loc[:, 'grp'] = np.random.randint(1, 101, df_sub.shape[0])
        rstl = p_map(find_time_zone, [g for _, g in df_sub.groupby('grp', group_keys=True)])
        df_sub = pd.concat(rstl)
        L_before = len(df_sub)
        df_sub = df_sub[df_sub.tzname.notna()]
        L_after = len(df_sub)
        print("Share of data remained after removing unknown timezone: %.2f %%" % (L_after / L_before * 100))
        self.data = pd.concat([df_de, df_sub.drop(columns=['grp'])])
        self.data = self.data.drop(columns=['de_time'])

    def convert_to_local_time(self):
        def zone_grp(k, data):
            data.loc[:, "localtime"] = data['datetime'].dt.tz_localize('UTC').dt.tz_convert(k)
            data.loc[:, "leaving_localtime"] = data['leaving_datetime'].dt.tz_localize('UTC').dt.tz_convert(k)
            return data
        mk = int(len(self.data)/2)
        part1 = self.data.iloc[:mk, :]
        part2 = self.data.iloc[mk:, :]
        print('Convert to local time: part 1.')
        rstl1 = p_map(zone_grp,
                     [k for k, _ in part1.groupby('tzname', group_keys=True)],
                     [g for _, g in part1.groupby('tzname', group_keys=True)])
        print('Convert to local time: part 2.')
        rstl2 = p_map(zone_grp,
                     [k for k, _ in part2.groupby('tzname', group_keys=True)],
                     [g for _, g in part2.groupby('tzname', group_keys=True)])
        self.data = pd.concat(rstl1 + rstl2)
        # print(self.data.iloc[0])

    def time_enrich(self):
        # Add start time hour and duration in minute
        for var, fx in zip(('localtime', 'leaving_localtime'), ('', 'leaving_')):
            self.data[var] = pd.to_datetime(self.data[var], errors='coerce')
            self.data.loc[:, f'{fx}hour'] = self.data.loc[:, var].dt.hour
            self.data.loc[:, f'{fx}weekday'] = self.data.loc[:, var].dt.dayofweek
            self.data.loc[:, f'{fx}week'] = self.data.loc[:, var].dt.isocalendar().week
            self.data.loc[:, f'{fx}date'] = self.data.loc[:, var].dt.date
        # Add individual sequence index
        self.data = self.data.sort_values(by=['device_aid', 'start'], ascending=True)

        def indi_seq(df):
            df.loc[:, 'seq'] = range(1, len(df) + 1)
            return df

        reslt = p_map(indi_seq, [g for _, g in self.data.groupby('device_aid', group_keys=True)])
        self.data = pd.concat(reslt)


def df2gdf_point(df, x_field, y_field, crs=4326, drop=True):
    """
    Convert two columns of GPS coordinates into POINT geo dataframe
    :param drop: boolean, if true, x and y columns will be dropped
    :param df: dataframe, containing X and Y
    :param x_field: string, col name of X
    :param y_field: string, col name of Y
    :param crs: int, epsg code
    :return: a geo dataframe with geometry of POINT
    """
    geometry = [Point(xy) for xy in zip(df[x_field], df[y_field])]
    if drop:
        gdf = GeoDataFrame(df.drop(columns=[x_field, y_field]), geometry=geometry)
    else:
        gdf = GeoDataFrame(df, crs=crs, geometry=geometry)
    gdf.set_crs(epsg=crs, inplace=True)
    return gdf