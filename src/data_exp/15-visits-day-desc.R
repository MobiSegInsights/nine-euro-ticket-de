# Title     : Visitation patterns (aggregate to labels)
# Objective : ... vs. day of the week (year-month)
# Created by: Yuan Liao
# Created on: 2024-05-03

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

df.y <- as.data.frame(read_parquet('results/yearly_poi_visitation_sg.parquet'))
df.lb <- as.data.frame(read_parquet('results/label_poi_visitation_sg.parquet'))
df <- as.data.frame(read_parquet('results/label_poi_visitation_delta_sg.parquet'))

# ---------------- No. of unique POIs by year and label ----
df.y.total <- df.y %>%
  group_by(year) %>%
  summarise(total_poi=sum(num_unique_poi))

df2plot <- merge(select(df.y, c('year', 'theme', 'label', 'num_unique_poi')),
                 df.y.total, on='year', how='left')
df2plot$poi_share <- df2plot$num_unique_poi / df2plot$total_poi * 100
df2plot <- arrange(df2plot, year, -poi_share)
lbs <- unique(df2plot$label)
df2plot$label <- factor(df2plot$label,
                        levels = lbs,
                        labels = lbs)

g1 <- ggplot(data = df2plot, aes(y=label, x=poi_share,
                                 color=as.factor(year),
                                 group=as.factor(year))) +
  theme_hc() +
  geom_point(alpha=0.6) +
  scale_color_discrete(name='Year') +
  labs(x = "POI share (%)", y = "POI type")

# ------ No. of unique devices by year and label ----
df2plot <- select(df.y, c('year', 'theme', 'label', 'num_unique_device'))
df2plot <- arrange(df2plot, year, -num_unique_device)
lbs <- unique(df2plot$label)
df2plot$label <- factor(df2plot$label,
                        levels = lbs,
                        labels = lbs)

g2 <- ggplot(data = df2plot, aes(y=label, x=num_unique_device/1000,
                                 color=as.factor(year),
                                 group=as.factor(year))) +
  theme_hc() +
  geom_point(alpha=0.6) +
  scale_color_discrete(name='Year') +
  labs(x = "No. of unique devices (x 1000)", y = "POI type")

# ------ No. of weighted pop visiting by year and label ----
df2plot <- select(df.y, c('year', 'theme', 'label', 'num_pop'))
df2plot <- arrange(df2plot, year, -num_pop)
lbs <- unique(df2plot$label)
df2plot$label <- factor(df2plot$label,
                        levels = lbs,
                        labels = lbs)

g3 <- ggplot(data = df2plot, aes(y=label, x=num_pop/1000000,
                                 color=as.factor(year),
                                 group=as.factor(year))) +
  theme_hc() +
  geom_point(alpha=0.6) +
  scale_color_discrete(name='Year') +
  labs(x = "No. of equivalent visitors (million)", y = "POI type")

G <- ggarrange(g1, g2, g3, ncol = 3, nrow = 1, labels = c('a', 'b', 'c'))
ggsave(filename = "figures/visits_day_desc/poi_share_year_sg.png", plot=G,
       width = 15, height = 7, unit = "in", dpi = 300, bg = 'white')

# ---- No. of unique devices by year, month, weekday, and label ----
# Top 24 types of locations
lbs.top <- lbs[1:24]

# Normalization
df.y.total <- df.y %>%
  select(year, theme, label, num_unique_device)

names(df.y.total)[names(df.y.total) == 'num_unique_device'] <- 'num_unique_device_a'
df2plot <- merge(select(df.lb, c('year', 'month', 'weekday', 'label', 'num_unique_device')),
                 df.y.total, on=c('year', 'label'), how='left')
df2plot$device_share <- df2plot$num_unique_device / df2plot$num_unique_device_a * 100

# Only check top 24 types of locations
df2plot <- df2plot[df2plot$label %in% lbs.top,]
df2plot <- df2plot[df2plot$month < 10,]

# Label month and weekdays
df2plot$weekday <- factor(df2plot$weekday,
                          levels = seq(0, 6),
                          labels = c('Mon', 'Tue', 'Wed', 'Thu', 'Fri',
                                     'Sat', 'Sun'))
df2plot$month <- factor(df2plot$month,
                          levels = seq(5, 9),
                          labels = c('May', 'Jun', 'Jul', 'Aug', 'Sep'))
df2plot.a <- df2plot %>%
  group_by(year, month, label) %>%
  summarise(device_share_a = mean(device_share))

df2plot <- merge(df2plot, df2plot.a, on=c('year', 'month', 'label'), how='left')

for (lb2plot in lbs.top) {
  g3 <- ggplot(data = df2plot[df2plot$label==lb2plot,],
               aes(y=device_share, x=weekday, color=as.factor(year), group=as.factor(year))) +
    theme_hc() +
    geom_line(alpha=0.3) +
    geom_point(alpha=0.3) +
    geom_line(aes(y=device_share_a, x=weekday, color=as.factor(year), group=as.factor(year))) +
    scale_color_discrete(name='Year') +
    facet_grid(.~month) +
    labs(x = "Day of the week", y = "Share of unique devices (%)", title = lb2plot) +
    theme(strip.background = element_blank())

  ggsave(filename = paste0("figures/visits_day_desc/sg_device_share_", lb2plot, ".png"),
         plot=g3, width = 10, height = 7, unit = "in", dpi = 300, bg = 'white')
}

# ---- No. of equivalent visitors by year, month, weekday, and label ----
# Top 24 types of locations
lbs.top <- lbs[1:24]

# Normalization
df.y.total <- df.y %>%
  select(year, theme, label, num_pop)

names(df.y.total)[names(df.y.total) == 'num_pop'] <- 'num_pop_a'
df2plot <- merge(select(df.lb, c('year', 'month', 'weekday', 'label', 'num_pop')),
                 df.y.total, on=c('year', 'label'), how='left')
df2plot$num_pop_share <- df2plot$num_pop / df2plot$num_pop_a * 100

# Only check top 24 types of locations
df2plot <- df2plot[df2plot$label %in% lbs.top,]
df2plot <- df2plot[df2plot$month < 10,]

# Label month and weekdays
df2plot$weekday <- factor(df2plot$weekday,
                          levels = seq(0, 6),
                          labels = c('Mon', 'Tue', 'Wed', 'Thu', 'Fri',
                                     'Sat', 'Sun'))
df2plot$month <- factor(df2plot$month,
                          levels = seq(5, 9),
                          labels = c('May', 'Jun', 'Jul', 'Aug', 'Sep'))
df2plot.a <- df2plot %>%
  group_by(year, month, label) %>%
  summarise(num_pop_share_a = mean(num_pop_share))

df2plot <- merge(df2plot, df2plot.a, on=c('year', 'month', 'label'), how='left')

for (lb2plot in lbs.top) {
  g4 <- ggplot(data = df2plot[df2plot$label==lb2plot,],
               aes(y=num_pop_share, x=weekday, color=as.factor(year), group=as.factor(year))) +
    theme_hc() +
    geom_line(alpha=0.3) +
    geom_point(alpha=0.3) +
    geom_line(aes(y=num_pop_share_a, x=weekday, color=as.factor(year), group=as.factor(year))) +
    scale_color_discrete(name='Year') +
    facet_grid(.~month) +
    labs(x = "Day of the week", y = "Share of visitors (%)", title = lb2plot) +
    theme(strip.background = element_blank())

  ggsave(filename = paste0("figures/visits_day_desc/visitors_share_", lb2plot, ".png"),
         plot=g4, width = 10, height = 7, unit = "in", dpi = 300, bg = 'white')
}

# Exclude 2019 data
for (lb2plot in lbs.top) {
  g3 <- ggplot(data = df2plot[(df2plot$label==lb2plot) & (df2plot$year != 2019),],
               aes(y=device_share, x=weekday, color=as.factor(year), group=as.factor(year))) +
    theme_hc() +
    geom_line(alpha=0.3) +
    geom_point(alpha=0.3) +
    geom_line(aes(y=device_share_a, x=weekday, color=as.factor(year), group=as.factor(year))) +
    scale_color_discrete(name='Year') +
    facet_grid(.~month) +
    labs(x = "Day of the week", y = "Share of unique devices (%)", title = lb2plot) +
    theme(strip.background = element_blank())

  ggsave(filename = paste0("figures/visits_day_desc/22_23_device_share_", lb2plot, ".png"),
         plot=g3, width = 10, height = 7, unit = "in", dpi = 300, bg = 'white')
}

# ---- Distance from home by year, month, weekday, and label (30, weighted) ----
# Top 24 types of locations
lbs.top <- lbs[1:24]
# Only check top 24 types of locations
df2plot <- df.lb[df.lb$label %in% lbs.top, c('year', 'month', 'weekday', 'label', 'd_ha_wt')]
df2plot <- df2plot[df2plot$month < 10,]

# Label month and weekdays
df2plot$weekday <- factor(df2plot$weekday,
                          levels = seq(0, 6),
                          labels = c('Mon', 'Tue', 'Wed', 'Thu', 'Fri',
                                     'Sat', 'Sun'))
df2plot$month <- factor(df2plot$month,
                          levels = seq(5, 9),
                          labels = c('May', 'Jun', 'Jul', 'Aug', 'Sep'))
df2plot.a <- df2plot %>%
  group_by(year, month, label) %>%
  summarise(d_ha_wt_a = mean(d_ha_wt))

df2plot <- merge(df2plot, df2plot.a, on=c('year', 'month', 'label'), how='left')

for (lb2plot in lbs.top) {
  g4 <- ggplot(data = df2plot[df2plot$label==lb2plot,],
               aes(y=d_ha_wt, x=weekday, color=as.factor(year), group=as.factor(year))) +
    theme_hc() +
    geom_line(alpha=0.3) +
    geom_point(alpha=0.3) +
    geom_line(aes(y=d_ha_wt_a, x=weekday, color=as.factor(year), group=as.factor(year))) +
    scale_color_discrete(name='Year') +
    facet_grid(.~month) +
    labs(x = "Day of the week", y = "Distance from home (weighted, km)", title = lb2plot) +
    theme(strip.background = element_blank())

  ggsave(filename = paste0("figures/visits_day_desc/sg_d2h_", lb2plot, ".png"),
         plot=g4, width = 10, height = 7, unit = "in", dpi = 300, bg = 'white')
}

# Exclude 2019 data (weighted)
for (lb2plot in lbs.top) {
  g3 <- ggplot(data = df2plot[(df2plot$label==lb2plot) & (df2plot$year != 2019),],
               aes(y=d_ha_wt, x=weekday, color=as.factor(year), group=as.factor(year))) +
    theme_hc() +
    geom_line(alpha=0.3) +
    geom_point(alpha=0.3) +
    geom_line(aes(y=d_ha_wt_a, x=weekday, color=as.factor(year), group=as.factor(year))) +
    scale_color_discrete(name='Year') +
    facet_grid(.~month) +
    labs(x = "Day of the week", y = "Distance from home (weighted, km)", title = lb2plot) +
    theme(strip.background = element_blank())

  ggsave(filename = paste0("figures/visits_day_desc/2223_d2h_", lb2plot, ".png"),
         plot=g3, width = 10, height = 7, unit = "in", dpi = 300, bg = 'white')
}

# ---- Delta values based on POIs above 30 visits ----
# lbs.top <- lbs[1:24]
lbs.top <- c('Restaurant', 'Supermarket', 'Recreation & Sports Centres', 'Retail stores')
df.device <- df %>%
  filter(var == 'num_visits_dd') %>%
  mutate(lower = q50_est-q50_se) %>%
  mutate(upper = q50_est+q50_se) %>%
  filter(label %in% lbs.top)

df.device$label <- factor(df.device$label,
                        levels = lbs.top,
                        labels = lbs.top)
df.device$weekday <- factor(df.device$weekday,
                          levels = seq(0, 6),
                          labels = c('Mon', 'Tue', 'Wed', 'Thu', 'Fri',
                                     'Sat', 'Sun'))

df.dh <- df %>%
  filter(var == 'd_ha_dd') %>%
  mutate(lower = q50_est-q50_se) %>%
  mutate(upper = q50_est+q50_se) %>%
  filter(label %in% lbs.top)

df.dh$label <- factor(df.dh$label,
                        levels = lbs.top,
                        labels = lbs.top)
df.dh$weekday <- factor(df.dh$weekday,
                          levels = seq(0, 6),
                          labels = c('Mon', 'Tue', 'Wed', 'Thu', 'Fri',
                                     'Sat', 'Sun'))

for (lb2plot in lbs.top) {
  g6 <- ggplot(data = df.device[df.device$label==lb2plot,], aes(x=weekday)) +
    theme_hc() +
    geom_linerange(aes(ymin=lower, ymax=upper), size=1, alpha=1) +
    geom_point(aes(y=q50_est), shape = 21, fill = "white", size = 2) +
    geom_hline(aes(yintercept = 0), color='gray', linewidth=1) +
    labs(title = lb2plot,
         x = 'Day of the week',
         y = 'No. of visits change') +
    theme(strip.background = element_blank())

  g7 <- ggplot(data = df.dh[df.dh$label==lb2plot,], aes(x=weekday)) +
    theme_hc() +
    geom_linerange(aes(ymin=lower, ymax=upper), size=1, alpha=1) +
    geom_point(aes(y=q50_est), shape = 21, fill = "white", size = 2) +
    geom_hline(aes(yintercept = 0), color='gray', linewidth=1) +

    labs(title = lb2plot,
         x = 'Day of the week',
         y = 'Distance from home change (km)') +
    theme(strip.background = element_blank())

  G1 <- ggarrange(g6, g7, ncol = 2, nrow = 1, labels = c('a', 'b'))
  ggsave(filename = paste0("figures/poi_cases/sg_delta_", lb2plot, ".png"),
           plot=G1, width = 10, height = 7, unit = "in", dpi = 300, bg = 'white')
}