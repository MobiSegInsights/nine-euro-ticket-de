import pandas as pd
import numpy as np
import os
import yaml
from pathlib import Path
os.environ['USE_PYGEOS'] = '0'
import cvxpy as cp
from linearmodels.panel import PanelOLS
import matplotlib.pyplot as plt
from tqdm import tqdm
import warnings
warnings.filterwarnings("ignore")


ROOT_dir = Path(__file__).parent.parent
with open(os.path.join(ROOT_dir, 'dbs', 'keys.yaml')) as f:
    keys_manager = yaml.load(f, Loader=yaml.FullLoader)


def data_preparation(data=None, year_list=[2019, 2022], treatment_yr=2022, break_pt=False,
                     treatment_months=[6, 7, 8], control_months=[5, ], unit='osm', unit_time='time'):
    df = data.copy()
    df = df.loc[df.year.isin(year_list), :]  # .drop_duplicates(subset=['osm_id', 'year', 'month', 'weekday'])
    months = treatment_months + control_months
    df = df.loc[df['month'].isin(months), :]

    # Categorization
    df['time_fe'] = df['state'].astype(str) + '-' +\
                    df['year'].astype(str) + '-' +\
                    df['month'].astype(str) # + '-' + df['weekday'].astype(str)
    # Create a state-year and state-month fixed effect
    df['state_month'] = df['state'].astype(str) + '_' + df['month'].astype(str)
    df['state_year'] = df['state'].astype(str) + '_' + df['year'].astype(str)
    df['state_weekday'] = df['state'].astype(str) + '_' + df['weekday'].astype(str)
    df['dow'] = df['weekday'].astype(int)
    # Time handling
    df['time'] = pd.to_datetime(df['date'])
    df['dow'] = df['weekday'].astype(int)
    for var in (f'{unit}_id', 'year', 'month', 'weekday', 'state_month', 'state_year','state_weekday', 'time_fe'):
        df[var] = df[var].astype('category')

    # Treatment
    df['post'] = df['year'] == treatment_yr
    df['rain'] = df['precipitation'] > 0
    df['rain_m'] = df['rain'] & df['post']  #
    df['9et'] = df['month'].isin(treatment_months)
    df['P_m'] = df['9et'] & df['post']  # post x 9ET

    # Add the dummy variable for treatment (P_m)
    if break_pt:
        # Add the dummy variable for treatment (P_m)
        df['P_m1'] = df['P_m'] & (df['pt_access'] == 'L')
        df['P_m2'] = df['P_m'] & (df['pt_access'] == 'M')
        df['P_m3'] = df['P_m'] & (df['pt_access'] == 'H')
        df['9et1'] = df['9et'] & (df['pt_access'] == 'L')
        df['9et2'] = df['9et'] & (df['pt_access'] == 'M')
        df['9et3'] = df['9et'] & (df['pt_access'] == 'H')

    # Set the multiindex
    df = df.set_index([f'{unit}_id', unit_time])
    return df


def data_prep_placebo(data=None, treatment_month=5, policy_t='20220511',
                      treatment_yr=2022, control_months=[5, ], p_9et=True, unit='osm', unit_time='time'):
    df = data.copy()
    if p_9et:
        df = df.loc[df['month'] == treatment_month, :]
    else:
        df = df.loc[df['month'].isin(control_months + [treatment_month]), :]
    # Categorization
    df['time_fe'] = df['state'].astype(str) + '-' +\
                    df['year'].astype(str) + '-' +\
                    df['month'].astype(str) # + '-' + df['weekday'].astype(str)
    # Create a state-year and state-month fixed effect
    df['state_month'] = df['state'].astype(str) + '_' + df['month'].astype(str)
    df['state_year'] = df['state'].astype(str) + '_' + df['year'].astype(str)
    df['state_weekday'] = df['state'].astype(str) + '_' + df['weekday'].astype(str)
    # Time handling
    df['time'] = pd.to_datetime(df['date'])
    df['dow'] = df['weekday'].astype(int)
    for var in (f'{unit}_id', 'year', 'month', 'weekday', 'state_month', 'state_year', 'state_weekday', 'time_fe'):
        df[var] = df[var].astype('category')

    # Treatment
    df['post'] = df['year'] == treatment_yr
    df['rain'] = df['precipitation'] > 0

    df.loc[:, 'date_time'] = pd.to_datetime(df['date'].astype(str), format='%Y-%m-%d')
    x = np.datetime64(pd.to_datetime(policy_t, format='%Y%m%d'))
    df['9et'] = (df['month'] == treatment_month) & (df['date_time'] >= x)

    # Add the dummy variable for treatment (P_m)
    df['P_m'] = df['9et'] & df['post']  # post x 9ET
    df['rain_m'] = df['rain'] & df['post']  #

    # Set the multiindex
    df = df.set_index([f'{unit}_id', unit_time])
    return df


def time_shifted_did(df=None, target_var='ln_num_visits_wt', time_effect='science', weight=False, break_pt=False):
    df2m = df.copy()
    # Define formula
    if break_pt:
        vars = ['P_m1', 'P_m2', 'P_m3', 'rain_m', 'rain', '9et1', '9et2', '9et3', 'gasoline']
        if time_effect == 'science':
            formula = f"{target_var} ~ P_m1 + P_m2 + P_m3 + rain_m" + \
                      " + rain + 9et1 + 9et2 + 9et3 + gasoline + EntityEffects + C(time_fe)"
        else:
            formula = f"{target_var} ~ P_m1 + P_m2 + P_m3 + rain_m" +\
                      " + rain + 9et1 + 9et2 + 9et3 + gasoline + EntityEffects" +\
                      " + C(state_year) + C(state_month) + C(weekday)"
    else:
        vars = ['P_m', 'rain_m', 'rain', '9et', 'gasoline']
        if time_effect == 'science':
            formula = f"{target_var} ~ P_m + rain_m + rain + 9et + gasoline + EntityEffects + C(time_fe)"
        else:
            formula = f"{target_var} ~ P_m + rain_m + rain + 9et + gasoline + EntityEffects" +\
                      " + C(state_year) + C(state_month) + C(weekday)"

    # Model specification
    model = PanelOLS.from_formula(
        formula,
        data=df2m,
        weights=df2m['weight'] if weight else None,
        check_rank=False,
        drop_absorbed=True
    )

    # Fit the model with clustering
    clusters = df2m.reset_index()['state']
    clusters.index = df2m.index
    result = model.fit(cov_type='clustered', clusters=clusters)

    metrics = []
    for var in vars:
        if var in result.params:
            metrics.append((var, result.params[var], result.pvalues[var], result.std_errors[var]))
    return result.summary, pd.DataFrame(metrics, columns=['variable', 'coefficient', 'pvalue', 'std_error'])


def place_filter_complete(data=None, control_y=None, treatment_y=None):
    def place_stats_ym(data):
        # comp = 8 means being complete
        comp_ym = len(data[['year', 'month']].drop_duplicates())
        comp_y = data['year'].nunique()
        return pd.Series(dict(comp_ym=comp_ym, comp_y=comp_y))

    tqdm.pandas()
    df_p = data.groupby('osm_id').progress_apply(place_stats_ym).reset_index()

    data = data.loc[data.osm_id.isin(df_p.loc[df_p.comp_y == 2, 'osm_id'].values), :]

    # Step 1: Group by 'osm_id', 'year', and 'month' to check for records
    monthly_presence = data.groupby(['osm_id', 'year', 'month']).size().unstack(fill_value=0)

    # Step 2: Check for 'osm_id's that have records in both years for the same month
    osm_ids_meeting_criteria = []
    for osm_id, row in tqdm(monthly_presence.groupby(level=0), 'The 9ET searching'):
        # Check each month across years for this osm_id
        if all((row.loc[(osm_id, control_y)] > 0) == (row.loc[(osm_id, treatment_y)] > 0)):
            osm_ids_meeting_criteria.append(osm_id)
    data = data.loc[data.osm_id.isin(osm_ids_meeting_criteria), :]
    return data


def data_filtering_and_weighting(data=None, control_y=None, treatment_y=None, covar='grdi',
                                 control_m=None, treatment_m=None, var=None, unit='osm'):
    """
     Creates a new dataset with weights of only two months for better comparison.
    """
    if control_y == 2019:
        data = data.loc[(data['date'] != '2019-05-14') & (data['date'] != '2022-05-14')]
    # Filter data for May-August 2019
    data_2019 = data[(data['year'] == control_y) & (data['month'].isin(control_m + treatment_m))].copy()

    # Filter data for May-August 2022
    data_2022 = data[(data['year'] == treatment_y) & (data['month'].isin(control_m + treatment_m))].copy()
    covariates = [var, covar]

    # Extract May 2019 data
    data_may_2019 = data_2019[data_2019['month'].isin(control_m)]

    # Compute target means from May 2019
    target_means = data_may_2019[covariates].mean().values

    # Extract May 2022 data
    data_may_2022 = data_2022[data_2022['month'].isin(control_m)]

    # Number of observations in May 2022
    n = data_may_2022.shape[0]

    # Covariate matrix for May 2022
    X = data_may_2022[covariates].values  # Shape: (n, k)

    # Initial weights (uniform)
    w0 = np.ones(n) / n  # Sum to 1

    # Define variable for weights
    w = cp.Variable(n)

    # Objective function: minimize KL divergence between w and w0
    objective = cp.Minimize(cp.sum(cp.kl_div(w, w0)))

    # Constraints
    constraints = [
        X.T @ w == target_means,
        cp.sum(w) == 1,
        w >= 0
    ]

    # Define and solve the problem
    problem = cp.Problem(objective, constraints)
    problem.solve(solver=cp.SCS, verbose=True, max_iters=5000)

    # Check if the optimization was successful
    if problem.status in ["infeasible", "unbounded"]:
        print("Optimization problem is infeasible or unbounded.")
    else:
        # Get the optimal weights
        weights_may_2022 = w.value
    # Map the weights to May-August 2022 data based on PlaceID
    weights_df = pd.DataFrame({
        f'{unit}_id': data_may_2022[f'{unit}_id'],
        'weight': weights_may_2022
    })

    # Merge weights into May-August 2022 data
    data_2022 = data_2022.merge(weights_df, on=f'{unit}_id', how='left')

    # Drop rows without weights (places not in May 2022 data)
    data_2022.dropna(subset=['weight'], inplace=True)
    data_2019['weight'] = 1 / data_2019.shape[0]

    # Combine May-August data for both years
    data_combined = pd.concat([data_2019, data_2022], ignore_index=True)
    data_combined.drop_duplicates(subset=[f'{unit}_id', 'date'], inplace=True)
    data_combined = data_combined.loc[data_combined['weight'] > 0]
    print(f"Number of unique places: {data_combined[f'{unit}_id'].nunique()}")
    return data_combined


def plot_target_var(data=None, var=None, year1=2019, year2=2022):
    # Calculate average daily visits by group and time
    avg_visits = data.groupby(['year', 'month', 'time', 'weekday'])[var].mean().reset_index()

    # Create a time variable for plotting
    avg_visits['Time'] = avg_visits['month'].astype(str) + \
                         '-' + avg_visits['weekday'].astype(str)
    # Plot the trends for treatment and control groups over time
    plt.figure(figsize=(10, 6))

    # Treatment group
    plt.plot(avg_visits[avg_visits['year'] == year2]['Time'],
             avg_visits[avg_visits['year'] == year2][var],
             label=f'Treatment year - {year2}', marker='o')

    # Control group
    plt.plot(avg_visits[avg_visits['year'] == year1]['Time'],
             avg_visits[avg_visits['year'] == year1][var],
             label=f'Baseline year - {year1}', marker='+')

    # Add vertical line to indicate start of treatment period (June 2022)
    plt.axvline(x='6-0', color='red', linestyle='--', label='Start of Treatment (June 2022)')

    plt.xlabel('Time')
    plt.ylabel('Average Number of Visits')
    plt.title(f'{year1} vs {year2}')
    plt.legend()
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.show()

