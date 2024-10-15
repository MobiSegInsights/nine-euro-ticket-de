# Title     : tdid input description
# Objective : time series
# Created by: Yuan Liao
# Created on: 2024-10-08


library(dplyr)
library(ggplot2)
library(ggpubr)
library(ggdensity)
library(scico)
library(arrow)
library(scales)
library(ggExtra)
library(ggthemes)
library(magick)
options(scipen=10000)

# tDiD input ----
df <- as.data.frame(read_parquet('results/tdid/high_pt_2019_2022.parquet')) %>%
  filter(grp=='treatment')

v_lines <- data.frame(
  xintercept = c(as.POSIXct("2022-06-01 02:00:00"), as.POSIXct("2022-06-01 02:00:00")),
  year = c(2022, 2022)
)

df.eff1 <- as.data.frame(read_parquet('results/tdid/high_pt_2019_2022_v_by_poi.parquet'))
df.eff1$y <- sub('^P_m_', '', df.eff1$y)
df.eff2 <- as.data.frame(read_parquet('results/tdid/high_pt_2019_2022_d_by_poi.parquet'))
df.eff2$y <- sub('^P_m_', '', df.eff2$y)

# Time series (visits) ----
summary_df1 <- df %>%
  group_by(time, year = format(time, "%Y")) %>%
  summarise(
    avg_visits = median(num_visits_wt, na.rm = TRUE),
    p25 = quantile(num_visits_wt, 0.25, na.rm = TRUE),
    p75 = quantile(num_visits_wt, 0.75, na.rm = TRUE)
  )

g1 <- ggplot(summary_df1, aes(x = time, y = avg_visits)) +
  geom_line(alpha=0.7, color='steelblue') +  # Plot the average number of visits over time
  geom_ribbon(aes(ymin = p25, ymax = p75), alpha = 0.2, fill='gray') +  # Shaded area for 25th to 75th percentile
  stat_smooth(
  color = "#FC4E07", fill = "#FC4E07",
  method = "loess"
  ) +
  geom_vline(data = v_lines, aes(xintercept = xintercept),
         linetype = "dashed", color = "#FC4E07", size=1) +
  labs(
    title = "Average Number of Visits Per Day",
    x = "Date",
    y = "Number of visits",
    fill = "Label",
    color = "Label"
  ) +
  facet_wrap(~year, scales = "free_x") +
  theme_hc() +
  theme(strip.background = element_blank(), legend.position = 'top')

# Time series (distance) ----
summary_df2 <- df %>%
  group_by(time, label, year = format(time, "%Y")) %>%
  summarise(
    avg_d = median(d_ha_wt, na.rm = TRUE),
    p25 = quantile(d_ha_wt, 0.25, na.rm = TRUE),
    p75 = quantile(d_ha_wt, 0.75, na.rm = TRUE)
  )

g2 <- ggplot(summary_df2, aes(x = time, y = avg_d)) +
  geom_line(alpha=0.7, color='steelblue') +  # Plot the average number of visits over time
  geom_ribbon(aes(ymin = p25, ymax = p75), alpha = 0.2, fill='gray') +  # Shaded area for 25th to 75th percentile
  stat_smooth(
  color = "#FC4E07", fill = "#FC4E07",
  method = "loess"
  ) +
  geom_vline(data = v_lines, aes(xintercept = xintercept),
           linetype = "dashed", color = "#FC4E07", size=1) +
  facet_wrap(~year, scales = "free_x") +
  scale_y_log10() +
  labs(
    title = "Distance from home (km)",
    x = "Date",
    y = "Distance from home (km)",
    fill = "Label",
    color = "Label"
  ) +
  theme_hc() +
  theme(strip.background = element_blank(), legend.position = 'top')

G <- ggarrange(g1, g2, ncol = 2, nrow = 1)
ggsave(filename = paste0("figures/tdid/high_pt_2019_2022_desc.png"),
       plot=G, width = 12, height = 5, unit = "in", dpi = 300, bg = 'white')

# 9ET effect ----
# Calculate confidence interval bounds
df.eff1$ci_low <- df.eff1$parameter - df.eff1$ci
df.eff1$ci_high <- df.eff1$parameter + df.eff1$ci

g3 <- ggplot(df.eff1, aes(x = parameter, y = reorder(y, parameter))) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray") +
  geom_point(size = 3) +
  geom_errorbarh(aes(xmin = ci_low, xmax = ci_high), height = 0.2) +
  labs(title = "Number of visits (%)",
       x = "Parameter Estimate",
       y = "Label") +
  theme_hc() +
  theme(axis.text.y = element_text(size = 12),
        axis.title = element_text(size = 14),
        plot.title = element_text(size = 16, hjust = 0.5),
        legend.position = "bottom")

df.eff2$ci_low <- df.eff2$parameter - df.eff2$ci
df.eff2$ci_high <- df.eff2$parameter + df.eff2$ci

g4 <- ggplot(df.eff2, aes(x = parameter, y = reorder(y, parameter))) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray") +
  geom_point(size = 3) +
  geom_errorbarh(aes(xmin = ci_low, xmax = ci_high), height = 0.2) +
  labs(title = "Distance from home (%)",
       x = "Parameter Estimate",
       y = "Label") +
  theme_hc() +
  theme(axis.text.y = element_text(size = 12),
        axis.title = element_text(size = 14),
        plot.title = element_text(size = 16, hjust = 0.5),
        legend.position = "bottom")

G2 <- ggarrange(g3, g4, ncol = 2, nrow = 1)
ggsave(filename = paste0("figures/tdid/high_pt_2019_2022_poi.png"),
       plot=G2, width = 12, height = 5, unit = "in", dpi = 300, bg = 'white')