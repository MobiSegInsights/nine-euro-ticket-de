# Title     : Visitation pattern cases
# Objective : Regular vs. recreational
# Created by: Yuan Liao
# Created on: 2024-06-03

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

# Regular ----
df.regular <- as.data.frame(read_parquet('results/poi_cases/supermarket.parquet'))
df.regular.stats <- df.regular %>%
  filter(weekday != 6) %>%
  group_by(name, year, month, weekday) %>%
  summarise(num_visits_wt = median(num_visits_wt),
            d_ha_wt = median(d_ha_wt))
  # mutate(num_visits_wt = num_visits_wt / max(num_visits_wt))

# Label month and weekdays
df.regular.stats$weekday <- factor(df.regular.stats$weekday,
                          levels = seq(0, 6),
                          labels = c('Mon', 'Tue', 'Wed', 'Thu', 'Fri',
                                     'Sat', 'Sun'))
df.regular.stats$month <- factor(df.regular.stats$month,
                          levels = seq(5, 9),
                          labels = c('May', 'Jun', 'Jul', 'Aug', 'Sep'))

g1 <- ggplot(data = df.regular.stats,
             aes(y=num_visits, x=weekday, color=as.factor(year), group=as.factor(year))) +
    theme_hc() +
    #geom_line(alpha=0.3) +
    geom_point(alpha=0.3) +
    geom_line(aes(y=num_visits, x=weekday, color=as.factor(year), group=as.factor(year))) +
    scale_color_discrete(name='Year') +
    facet_grid(name~month) +
    labs(x = "Day of the week", y = "No. of visits",
         title = 'Supermarkets (171) - Visits') +
    theme(strip.background = element_blank())

g2 <- ggplot(data = df.regular.stats,
             aes(y=d_ha, x=weekday, color=as.factor(year), group=as.factor(year))) +
    theme_hc() +
    #geom_line(alpha=0.3) +
    geom_point(alpha=0.3) +
    geom_line(aes(y=d_ha, x=weekday, color=as.factor(year), group=as.factor(year))) +
    scale_color_discrete(name='Year') +
    facet_grid(name~month) +
    labs(x = "Day of the week", y = "Distance from home (km)",
         title = 'Supermarkets (171) - Distance from home') +
    theme(strip.background = element_blank())

ggsave(filename = paste0("figures/poi_cases/Supermarket_v.png"),
       plot=g1, width = 10, height = 7, unit = "in", dpi = 300, bg = 'white')
ggsave(filename = paste0("figures/poi_cases/Supermarket_d2h.png"),
       plot=g2, width = 10, height = 7, unit = "in", dpi = 300, bg = 'white')

# Recreational (Tourist attractions) ----
df.rec <- as.data.frame(read_parquet('results/poi_cases/recreation & sports centres.parquet'))
# Label month and weekdays
df.rec$weekday <- factor(df.rec$weekday,
                          levels = seq(0, 6),
                          labels = c('Mon', 'Tue', 'Wed', 'Thu', 'Fri',
                                     'Sat', 'Sun'))
df.rec$month <- factor(df.rec$month,
                          levels = seq(5, 9),
                          labels = c('May', 'Jun', 'Jul', 'Aug', 'Sep'))

g3 <- ggplot(data = df.rec,
             aes(y=num_visits, x=weekday, color=as.factor(year), group=as.factor(year))) +
    theme_hc() +
    #geom_line(alpha=0.3) +
    geom_point(alpha=0.3) +
    geom_line(aes(y=num_visits, x=weekday, color=as.factor(year), group=as.factor(year))) +
    scale_color_discrete(name='Year') +
    facet_grid(name~month) +
    labs(x = "Day of the week", y = "No. of visits",
         title = 'Tourist attractions (3) - Visits') +
    theme(strip.background = element_blank())

g31 <- ggplot(data = df.rec[df.rec$name != 'Schwanentempel',],
             aes(y=num_visits, x=weekday, color=as.factor(year), group=as.factor(year))) +
    theme_hc() +
    #geom_line(alpha=0.3) +
    geom_point(alpha=0.3) +
    geom_line(aes(y=num_visits, x=weekday, color=as.factor(year), group=as.factor(year))) +
    scale_color_discrete(name='Year') +
    facet_grid(name~month) +
    labs(x = "Day of the week", y = "No. of visits",
         title = 'Tourist attractions (2) - Visits') +
    theme(strip.background = element_blank())

g4 <- ggplot(data = df.rec[df.rec$name != 'Schwanentempel',],
             aes(y=d_ha_wt, x=weekday, color=as.factor(year), group=as.factor(year))) +
    theme_hc() +
    #geom_line(alpha=0.3) +
    geom_point(alpha=0.3) +
    geom_line(aes(y=d_ha_wt, x=weekday, color=as.factor(year), group=as.factor(year))) +
    scale_color_discrete(name='Year') +
    facet_grid(name~month) +
    labs(x = "Day of the week", y = "Distance from home (km)",
         title = 'Tourist attractions (2) - Distance from home') +
    theme(strip.background = element_blank())
g4
ggsave(filename = paste0("figures/poi_cases/Tourist attractions_v_error.png"),
       plot=g3, width = 10, height = 7, unit = "in", dpi = 300, bg = 'white')
ggsave(filename = paste0("figures/poi_cases/Tourist attractions_v.png"),
       plot=g31, width = 10, height = 7, unit = "in", dpi = 300, bg = 'white')
ggsave(filename = paste0("figures/poi_cases/Tourist attractions_d2h.png"),
       plot=g4, width = 10, height = 7, unit = "in", dpi = 300, bg = 'white')

# DiD prep. parallel trend (Regular) ----
df.did <- df.regular.stats %>%
  filter(name=='Lidl') %>%
  filter(month %in% c('May', 'Jun', 'Jul', 'Aug')) %>%
  filter(year %in% c(2019, 2022))

g5 <- ggplot(data = df.did,
             aes(y=d_ha_wt, x=weekday, color=as.factor(month), group=as.factor(month))) +
    theme_hc() +
    geom_point(alpha=0.3) +
    geom_line(aes(y=d_ha_wt, x=weekday, color=as.factor(month), group=as.factor(month))) +
    scale_color_discrete(name='Year') +
    facet_grid(.~year) +
    labs(x = "Day of the week", y = "Distance from home (km)",
         title = 'Lidl - Distance from home') +
    theme(strip.background = element_blank())

g6 <- ggplot(data = df.did,
             aes(y=num_visits_wt, x=weekday, color=as.factor(month), group=as.factor(month))) +
    theme_hc() +
    #geom_line(alpha=0.3) +
    geom_point(alpha=0.3) +
    geom_line(aes(y=num_visits_wt, x=weekday, color=as.factor(month), group=as.factor(month))) +
    scale_color_discrete(name='Year') +
    facet_grid(.~year) +
    labs(x = "Day of the week", y = "No. of visits",
         title = 'Lidl - No. of visits') +
    theme(strip.background = element_blank())

G <- ggarrange(g5, g6, ncol = 2, nrow = 1, labels = c('a', 'b'))
G
ggsave(filename = paste0("figures/poi_cases/sg_did_prep_supermarket.png"),
         plot=G, width = 10, height = 7, unit = "in", dpi = 300, bg = 'white')

# DiD prep. parallel trend (Retail stores) ----
df.rec <- as.data.frame(read_parquet('results/poi_cases/retail.parquet'))
# Label month and weekdays
df.rec$weekday <- factor(df.rec$weekday,
                          levels = seq(0, 6),
                          labels = c('Mon', 'Tue', 'Wed', 'Thu', 'Fri',
                                     'Sat', 'Sun'))
df.rec$month <- factor(df.rec$month,
                          levels = seq(5, 9),
                          labels = c('May', 'Jun', 'Jul', 'Aug', 'Sep'))

df.did <- df.rec %>%
  filter(month %in% c('May', 'Jun')) %>%
  filter(year %in% c(2019, 2022))

g7 <- ggplot(data = df.did,
             aes(y=d_ha_wt, x=weekday, color=as.factor(month), group=as.factor(month))) +
    theme_hc() +
    geom_point(alpha=0.3) +
    geom_line(aes(y=d_ha_wt, x=weekday, color=as.factor(month), group=as.factor(month))) +
    scale_color_discrete(name='Year') +
    facet_grid(.~year) +
    labs(x = "Day of the week", y = "Distance from home (km)",
         title = "Marion's Blumenstubchen - Distance from home") +
    theme(strip.background = element_blank())

g8 <- ggplot(data = df.did,
             aes(y=num_visits_wt, x=weekday, color=as.factor(month), group=as.factor(month))) +
    theme_hc() +
    #geom_line(alpha=0.3) +
    geom_point(alpha=0.3) +
    geom_line(aes(y=num_visits_wt, x=weekday, color=as.factor(month), group=as.factor(month))) +
    scale_color_discrete(name='Year') +
    facet_grid(.~year) +
    labs(x = "Day of the week", y = "No. of visits",
         title = "Marion's Blumenstubchen - No. of visits") +
    theme(strip.background = element_blank())

G2 <- ggarrange(g7, g8, ncol = 2, nrow = 1, labels = c('a', 'b'))
ggsave(filename = paste0("figures/poi_cases/sg_did_prep_retail.png"),
         plot=G2, width = 10, height = 7, unit = "in", dpi = 300, bg = 'white')