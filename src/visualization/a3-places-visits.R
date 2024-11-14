library(dplyr)
library(ggplot2)
library(ggpubr)
library(ggsci)
library(ggdensity)
library(scico)
library(arrow)
library(scales)
library(ggExtra)
library(ggthemes)
library(shadowtext)
options(scipen=10000)

df <- as.data.frame(read_parquet('results/stats/places_visits.parquet'))
df.date <- as.data.frame(read_parquet('results/stats/date_stats.parquet'))
df.ym <- as.data.frame(read_parquet('results/stats/places_ym.parquet'))
df.ym$month <- month.abb[df.ym$month]
df.ym$month <- factor(df.ym$month, levels = month.abb[2:9], ordered = TRUE)
df.place <- as.data.frame(read_parquet('results/stats/places_share4models.parquet'))
df.place$month <- month.abb[df.place$month]
df.place$month <- factor(df.place$month, levels = month.abb[2:9], ordered = TRUE)
df.place <- df.place %>%
  arrange(share)
lbs <- unique(df.place$label)
df.place$label <- factor(df.place$label, levels = lbs, labels = lbs)

top_labels <- df %>%
  filter(visit_thr == 0) %>%     # Filter rows where threshold is 0
  arrange(desc(place_count)) %>%         # Sort by 'num' in descending order
  slice_head(n = 6)             # Select the top 11 rows

g1 <- ggplot(data = df[df$label %in% top_labels$label,]) +
  theme_hc() +
  geom_vline(xintercept=4, color='gray') +
  geom_point(aes(x=as.factor(visit_thr + 1), y=place_count, color=label)) +
  geom_line(aes(x=as.factor(visit_thr + 1), y=place_count, color=label, group=label)) +
  scale_color_npg(name='Place type') +
  scale_y_log10() +
  # Labels and theme adjustments
  labs(y = "No. of places", x = "Minimum daily no. of unique visitors")

top8_labels <- df %>%
  filter(visit_thr == 0) %>%     # Filter rows where threshold is 0
  arrange(desc(place_count)) %>%         # Sort by 'num' in descending order
  slice_head(n = 8)             # Select the top 11 rows



g21 <- ggplot(df.place[df.place$policy=='9ET',],
             aes(x = month, y = share, fill = label)) +
  geom_bar(stat = 'identity') +
  theme_hc() +
  facet_wrap(~year) +
  # Labels and theme adjustment
  scale_fill_npg(name='Share') +
  labs(x = "Month", y = "Share of records (%)") +
  geom_text(aes(label = round(share, digits=1)), colour = "white", size = 3,
            position = position_stack(vjust = .5), fontface = "bold") +
  theme(legend.position = 'bottom',
        plot.title = element_text(hjust = 0, face = "bold"),
        axis.text.x = element_text(angle = 0, vjust = 0.5, hjust=0.5),
        panel.grid = element_blank(), strip.background = element_blank())

g22 <- ggplot(df.place[df.place$policy=='DT',],
             aes(x = month, y = share, fill = label)) +
  geom_bar(stat = 'identity') +
  theme_hc() +
  facet_wrap(~year) +
  # Labels and theme adjustment
  scale_fill_npg(name='Share') +
  labs(x = "Month", y = "Share of records (%)") +
  geom_text(aes(label = round(share, digits=1)), colour = "white", size = 3,
            position = position_stack(vjust = .5), fontface = "bold") +
  theme(legend.position = 'bottom',
        plot.title = element_text(hjust = 0, face = "bold"),
        axis.text.x = element_text(angle = 0, vjust = 0.5, hjust=0.5),
        panel.grid = element_blank(), strip.background = element_blank())

G2 <- ggarrange(g21, g22, ncol = 2, nrow = 1, labels = c('b', 'c'),
                common.legend = T, legend="bottom")
G <- ggarrange(g1, G2, ncol = 2, nrow = 1, widths = c(1, 1.4), labels = c('a', ''))
ggsave(filename = paste0("figures/manuscript/place_labels.png"),
       plot=G, width = 14.5, height = 6, unit = "in", dpi = 300, bg = 'white')

g4 <- ggplot() +
  theme_hc() +
  # Add the heatmap tiles
  geom_tile(data = df.ym, aes(x = month, y = as.factor(year), fill = num_places/1000),
            colour = "white", width = 1, height = 1) +
  # Color scale
  scale_fill_scico(name = "No. of places",
                   palette = "bamako", label = scales::comma) +
  # Add the text labels with device count in each tile
  geom_shadowtext(data = df.ym, aes(x = month, y = as.factor(year),
                                    label = sprintf("%.1f", num_places/1000)),
                  color = "black",                # Text color
                  bg.color = "white",             # Outline color
                  bg.r = 0.15,                    # Outline thickness
                  size = 4) +                     # Text size
  # Labels and theme adjustments
  labs(y = "Year", x = "Month") +
  scale_y_discrete(limits = rev(levels(as.factor(df.ym$year)))) +
  scale_x_discrete(position = "top") +
  theme(legend.position = "bottom", legend.key.width = unit(1, "cm"),
        panel.grid = element_blank())

# Create a new column with month and day only
df.date$date <- as.Date(df.date$date)
df.date$month_day <- format(df.date$date, "%m-%d")  # Extract month and day as "MM-DD"
v_lines1 <- data.frame(
  xintercept = c('06-01', '06-01'),
  year = c(2022, 2022)
)
v_lines2 <- data.frame(
  xintercept = c('05-02', '05-02'),
  year = c(2023, 2023)
)

g31 <- ggplot(data = df.date[df.date$policy=='9ET',],
              aes(x = month_day, y = v50, group=as.factor(year))) +
  theme_hc() +
  geom_line(size=0.5) +
  geom_ribbon(aes(ymin = v25, ymax = v75), alpha = 0.2, fill='gray') +
  stat_smooth(
  color = "#ffa801", fill = "#ffa801",
  method = "loess"
  ) +
  geom_vline(data = v_lines1, aes(xintercept = xintercept),
         linetype = "dashed", color = "#ffa801", size=1) +
  facet_wrap(~year) +
  # Labels and theme adjustments
  labs(x = "Date", y = "No. of visits") +
  scale_x_discrete(breaks = c("02-01", "03-01", "04-01",
                              "05-02", "06-01", "07-01",
                              "08-01"),
  labels = c("Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug")) +  # Adjust x-axis labels if needed
  theme(panel.grid = element_blank(), strip.background = element_blank())

g32 <- ggplot(data = df.date[df.date$policy=='9ET',],
              aes(x = month_day, y = d50, group=as.factor(year))) +
  theme_hc() +
  geom_line(size=0.5) +
  geom_ribbon(aes(ymin = d25, ymax = d75), alpha = 0.2, fill='gray') +
  stat_smooth(
  color = "#ffa801", fill = "#ffa801",
  method = "loess"
  ) +
  geom_vline(data = v_lines1, aes(xintercept = xintercept),
         linetype = "dashed", color = "#ffa801", size=1) +
  facet_wrap(~year) +
  # Labels and theme adjustments
  labs(x = "Date", y = "Distance from home (km)") +
  scale_x_discrete(breaks = c("02-01", "03-01", "04-01",
                              "05-02", "06-01", "07-01",
                              "08-01"),
  labels = c("Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug")) +  # Adjust x-axis labels if needed
  theme(panel.grid = element_blank(), strip.background = element_blank())

g33 <- ggplot(data = df.date[df.date$policy=='DT',],
              aes(x = month_day, y = v50, group=as.factor(year))) +
  theme_hc() +
  geom_line(size=0.5) +
  geom_ribbon(aes(ymin = v25, ymax = v75), alpha = 0.2, fill='gray') +
  stat_smooth(
  color = "#0fbcf9", fill = "#0fbcf9",
  method = "loess"
  ) +
  geom_vline(data = v_lines2, aes(xintercept = xintercept),
         linetype = "dashed", color = "#0fbcf9", size=1) +
  facet_wrap(~year) +
  # Labels and theme adjustments
  labs(x = "Date", y = "No. of visits") +
  scale_x_discrete(breaks = c("02-01", "03-01", "04-01",
                              "05-02", "06-01", "07-01",
                              "08-01"),
  labels = c("Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug")) +  # Adjust x-axis labels if needed
  theme(panel.grid = element_blank(), strip.background = element_blank())

g34 <- ggplot(data = df.date[df.date$policy=='DT',],
              aes(x = month_day, y = d50, group=as.factor(year))) +
  theme_hc() +
  geom_line(size=0.5) +
  geom_ribbon(aes(ymin = d25, ymax = d75), alpha = 0.2, fill='gray') +
  stat_smooth(
  color = "#0fbcf9", fill = "#0fbcf9",
  method = "loess"
  ) +
  geom_vline(data = v_lines2, aes(xintercept = xintercept),
         linetype = "dashed", color = "#0fbcf9", size=1) +
  facet_wrap(~year) +
  # Labels and theme adjustments
  labs(x = "Date", y = "Distance from home (km)") +
  scale_x_discrete(breaks = c("02-01", "03-01", "04-01",
                              "05-02", "06-01", "07-01",
                              "08-01"),
  labels = c("Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug")) +  # Adjust x-axis labels if needed
  theme(panel.grid = element_blank(), strip.background = element_blank())

G3 <- ggarrange(g31, g33, g32, g34, ncol = 2, nrow = 2, labels = c('a', 'b', 'c', 'd'))
ggsave(filename = paste0("figures/manuscript/visits_distance_time_series.png"),
       plot=G3, width = 12, height = 7, unit = "in", dpi = 300, bg = 'white')

