# Title     : No. of geolocations by year and month
# Objective : Describe the raw data (GPS records)
# Created by: Yuan Liao
# Created on: 2024-10-28

library(dplyr)
library(ggplot2)
library(ggpubr)
library(ggdensity)
library(scico)
library(arrow)
library(scales)
library(ggExtra)
library(ggthemes)
library(shadowtext)
options(scipen=10000)

df <- as.data.frame(read_parquet('results/stats/raw_records_stats.parquet'))
df$month <- month.abb[df$month]
df$month <- factor(df$month, levels = month.abb[2:9], ordered = TRUE)

# only show DT time period
df <- df %>%
  filter(year != 2019) %>%
  filter(month %in% c('Mar', 'Apr', 'May'))

# Plot
g1 <- ggplot() +
  theme_hc() +
  # Add the heatmap tiles
  geom_tile(data = df, aes(x = month, y = as.factor(year), fill = device_count),
            colour = "white", width = 1, height = 1) +
  # Color scale
  scale_fill_scico(name = "No. of devices (million)",
                   palette = "bamako", label = scales::comma) +
  # Add the text labels with device count in each tile
  geom_shadowtext(data = df, aes(x = month, y = as.factor(year), label = sprintf("%.1f", device_count)),
                  color = "black",                # Text color
                  bg.color = "white",             # Outline color
                  bg.r = 0.15,                    # Outline thickness
                  size = 4) +                     # Text size
  # Labels and theme adjustments
  labs(y = "Year", x = "Month") +
  scale_y_discrete(limits = rev(levels(as.factor(df$year)))) +
  scale_x_discrete(position = "top") +
  theme(legend.position = "bottom", legend.key.width = unit(1, "cm"),
        panel.grid = element_blank())

g2 <- ggplot() +
  theme_hc() +
  # Add the heatmap tiles
  geom_tile(data = df, aes(x = month, y = as.factor(year), fill = rec_count/1000),
            colour = "white", width = 1, height = 1) +
  # Color scale
  scale_fill_scico(name = "No. of geolocations (billion)",
                   palette = "bamako", label = scales::comma) +
  # Add the text labels with device count in each tile
  geom_shadowtext(data = df, aes(x = month, y = as.factor(year), label = sprintf("%.1f", rec_count/1000)),
                  color = "black",                # Text color
                  bg.color = "white",             # Outline color
                  bg.r = 0.15,                    # Outline thickness
                  size = 4) +                     # Text size
  # Labels and theme adjustments
  labs(y = "Year", x = "Month") +
  scale_y_discrete(limits = rev(levels(as.factor(df$year)))) +
  scale_x_discrete(position = "top") +
  theme(legend.position = "bottom", legend.key.width = unit(1, "cm"),
        panel.grid = element_blank())


G <- ggarrange(g1, g2, ncol = 2, nrow = 1, labels = c('a', 'b'))
G
ggsave(filename = "figures/manuscript/a1_raw_data_stats.png", plot=G,
       width = 10, height = 3, unit = "in", dpi = 300, bg = 'white')