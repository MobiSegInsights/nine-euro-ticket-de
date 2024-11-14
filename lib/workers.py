import os
import yaml
import pandas as pd
from pathlib import Path
import numpy as np
from datetime import datetime
from tqdm import tqdm
from p_tqdm import p_map
from statsmodels.stats.weightstats import DescrStatsW
from geopandas import GeoDataFrame
from shapely.geometry import Point
from math import radians, cos, sin, asin, sqrt
from timezonefinder import TimezoneFinder
from shapely.geometry import Polygon
import warnings
warnings.simplefilter(action='ignore', category=FutureWarning)


ROOT_dir = Path(__file__).parent.parent
with open(os.path.join(ROOT_dir, 'dbs', 'keys.yaml')) as f:
    keys_manager = yaml.load(f, Loader=yaml.FullLoader)


de_box = (5.98865807458, 47.3024876979, 15.0169958839, 54.983104153)


# Function to create a 100m x 100m square polygon
def create_square(x, y, size=100):
    half_size = size / 2
    return Polygon([
        (x - half_size, y - half_size),
        (x + half_size, y - half_size),
        (x + half_size, y + half_size),
        (x - half_size, y + half_size)
    ])


def bootstrap_median_and_error(df, target_col, weight_col, n_bootstrap=1000):
    """
    Calculate the bootstrap median and error of a dataframe with target value and weight columns.

    Parameters:
    - df: pandas DataFrame containing the data
    - target_col: str, name of the target value column
    - weight_col: str, name of the weight column
    - n_bootstrap: int, number of bootstrap samples to draw

    Returns:
    - median: float, estimated median of the target values
    - median_error: float, standard error of the bootstrap medians
    """
    target_values = df[target_col].values
    wts = df[weight_col].values

    bootstrap_medians = []

    for _ in range(n_bootstrap):
        # Resample with replacement
        resample_indices = np.random.choice(len(target_values), size=len(target_values), replace=True)
        resampled_values = target_values[resample_indices]
        resampled_weights = wts[resample_indices]

        # Calculate weighted median for resample
        wdf = DescrStatsW(resampled_values, weights=resampled_weights, ddof=1)
        sts = wdf.quantile([0.50])
        median = sts.values[0]
        bootstrap_medians.append(median)

    # Calculate the median and standard error of the bootstrap medians
    median_estimate = np.median(bootstrap_medians)
    median_error = np.std(bootstrap_medians)

    return median_estimate, median_error


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
        # Focus on Germany, skipping functions of time_zone_parallel and convert_to_local_time
        self.data = self.data.loc[self.data['de_time'] == 1, :]
        k = 'Europe/Berlin'
        self.data = self.data.drop(columns=['de_time'])
        self.data.loc[:, "localtime"] = self.data['datetime'].dt.tz_localize('UTC').dt.tz_convert(k)
        print('Time processed done.')

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
        self.data.loc[:, 'month'] = self.data.loc[:, 'localtime'].dt.month
        self.data.loc[:, 'year'] = self.data.loc[:, 'localtime'].dt.year
        self.data.loc[:, 'weekday'] = self.data.loc[:, 'localtime'].dt.dayofweek
        self.data.loc[:, 'week'] = self.data.loc[:, 'localtime'].dt.isocalendar().week
        self.data.loc[:, 'date'] = self.data.loc[:, 'localtime'].dt.date
        # Add individual sequence index
        self.data = self.data.sort_values(by=['device_aid', 'timestamp'], ascending=True)
        #
        # def indi_seq(df):
        #     df.loc[:, 'seq'] = range(1, len(df) + 1)
        #     return df
        #
        # reslt = p_map(indi_seq, [g for _, g in self.data.groupby('device_aid', group_keys=True)])
        # self.data = pd.concat(reslt)


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
    :param x_field: string, col name of X, lng
    :param y_field: string, col name of Y, lat
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


def haversine(lon1, lat1, lon2, lat2):
    """
    Calculate the great circle distance between two points
    on the earth (specified in decimal degrees) in km
    """
    # convert decimal degrees to radians
    lon1, lat1, lon2, lat2 = map(radians, [lon1, lat1, lon2, lat2])

    # haversine formula
    dlon = lon2 - lon1
    dlat = lat2 - lat1
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    c = 2 * asin(sqrt(a))
    r = 6371 # Radius of earth in kilometers. Use 3956 for miles
    return c * r


def haversine_vec(data):
    """
    Take array of zones' centroids to return the Haversine distance matrix
    :param data: 2d array e.g., list(zones.loc[:, ["Y", "X"]].values)
    :return: a matrix of distance
    """
    # Convert to radians
    data = np.deg2rad(data)

    # Extract col-1 and 2 as latitudes and longitudes
    lat = data[:, 0]
    lng = data[:, 1]

    # Elementwise differentiations for latitudes & longitudes
    diff_lat = lat[:, None] - lat
    diff_lng = lng[:, None] - lng

    # Finally Calculate haversine
    d = np.sin(diff_lat / 2) ** 2 + np.cos(lat[:, None]) * np.cos(lat) * np.sin(diff_lng / 2) ** 2
    return 2 * 6371 * np.arcsin(np.sqrt(d))