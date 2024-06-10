# Title     : DiD tests results (basic)
# Objective : var, place type, treament month, control year
# Created by: Yuan Liao
# Created on: 2024-06-04

library(dplyr)
library(ggplot2)
library(ggpubr)
library(ggdensity)
library(scico)
library(arrow)
library(scales)
library(ggExtra)
library(ggthemes)
options(scipen=10000)

# Basic DiD test ----
df <- as.data.frame(read_parquet('results/did/basic_did.parquet'))
lbs.top <- c('Restaurant', 'Supermarket', 'Recreation & Sports Centres', 'Retail stores')
df <- df %>%
  filter(pvalue < 0.001) %>%
  mutate(lower = parameter-ci) %>%
  mutate(upper = parameter+ci)

df$target_var <- factor(df$target_var,
                       levels = c('num_visits_wt', 'd_ha_wt'),
                        labels = c('No. of visits', 'Distance from home (km)'))

df$treatment_month <- factor(df$treatment_month,
                       levels = seq(6, 8), labels = c('Jun', 'Jul', 'Aug'))

g1 <- ggplot(data = df, aes(x=treatment_month, color=as.factor(compare_year))) +
    theme_hc() +
    geom_linerange(aes(ymin=lower, ymax=upper),
                   size=1, alpha=1, position = position_dodge(.7)) +
    geom_point(aes(y=parameter),
               shape = 21, fill = "white", size = 2,
               position = position_dodge(.7)) +
    geom_hline(aes(yintercept = 0), color='gray', linewidth=1) +
    facet_grid(target_var~place_type, scales = "free_y")+
    scale_color_manual(name='Control year',
                       breaks = c(2019, 2023),
                       values = c('darkred', 'darkgreen'),
    ) +
    labs(x = 'Treatment month',
         y = '9ET effect') +
    theme(strip.background = element_blank())
ggsave(filename = paste0("figures/did/basics.png"),
           plot=g1, width = 8, height = 4, unit = "in", dpi = 300, bg = 'white')

# DiD models ----
df <- as.data.frame(read_parquet('results/did/did_models_30.parquet'))
lbs.top <- c('Restaurant', 'Supermarket', 'Recreation & Sports Centres', 'Retail stores')
df <- df %>%
  filter(pvalue < 0.001) %>%
  mutate(lower = parameter-ci) %>%
  mutate(upper = parameter+ci)

df$target_var <- factor(df$target_var,
                       levels = c('num_visits_wt', 'd_ha_wt'),
                        labels = c('No. of visits', 'Distance from home (km)'))

df$treatment_month <- factor(df$treatment_month,
                       levels = seq(6, 8), labels = c('Jun', 'Jul', 'Aug'))

g2 <- ggplot(data = df, aes(x=treatment_month, color=as.factor(compare_year))) +
    theme_hc() +
    geom_linerange(aes(ymin=lower, ymax=upper),
                   size=1, alpha=1, position = position_dodge(.7)) +
    geom_point(aes(y=parameter),
               shape = 21, fill = "white", size = 2,
               position = position_dodge(.7)) +
    geom_hline(aes(yintercept = 0), color='gray', linewidth=1) +
    facet_grid(target_var~place_type, scales = "free_y")+
    scale_color_manual(name='Control year',
                       breaks = c(2019, 2023),
                       values = c('darkred', 'darkgreen'),
    ) +
    labs(x = 'Treatment month',
         y = '9ET effect') +
    theme(strip.background = element_blank())
ggsave(filename = paste0("figures/did/models_30.png"),
           plot=g2, width = 9, height = 4.5, unit = "in", dpi = 300, bg = 'white')

# DiD Model 2 ----
df <- as.data.frame(read_parquet('results/did/did_model_2.parquet'))
df <- df %>%
  filter((pvalue < 0.05) & (placebo == 1)) %>%
  mutate(lower = parameter-ci) %>%
  mutate(upper = parameter+ci)

df$target_var <- factor(df$target_var,
                       levels = c('num_visits_wt', 'd_ha_wt'),
                        labels = c('No. of visits', 'Distance from home (km)'))

df$y <- factor(df$y, levels = c('after', 'P_m'),
               labels = c('June-Aug', '9ET scheme'))
df.2019 <- arrange(df[df$compare_year==2019,], target_var, y, -parameter)
df.2023 <- arrange(df[df$compare_year==2023,], target_var, y, -parameter)
df <- rbind(df.2019, df.2023)

g3 <- ggplot(data = df, aes(y=place, color=y)) +
    theme_hc() +
    geom_vline(xintercept = 0, size=0.1) +
    geom_linerange(aes(xmin=lower, xmax=upper),
                   size=1, alpha=1, position = position_dodge(.7)) +
    geom_point(aes(x=parameter),
               shape = 21, fill = "white", size = 2,
               position = position_dodge(.7)) +
    geom_hline(aes(yintercept = 0), color='gray', linewidth=1) +
    facet_grid(target_var~as.factor(compare_year), scales = "free")+
    scale_color_manual(name='Effect',
                       breaks = c('June-Aug', '9ET scheme'),
                       values = c('gray45', 'steelblue'),
    ) +
    labs(y = 'Place type',
         x = '9ET effect') +
    theme(strip.background = element_blank())
g3
ggsave(filename = paste0("figures/did/model2.png"),
           plot=g3, width = 10, height = 10, unit = "in", dpi = 300, bg = 'white')

# DiD Model 2 Full 2022 vs. 2023 (Jun-Aug) ----
df <- as.data.frame(read_parquet('results/did/all_states_model_v5_pt3_pois_6_8.parquet'))
