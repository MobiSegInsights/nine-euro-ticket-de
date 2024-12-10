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

# 'age', 'all', 'birth_f', 'deprivation', 'net_rent', 'pop_density'
gp <- 'all'
lv <- 'all'
# df.date <- as.data.frame(read_parquet(paste0('results/hex_time_series/', gp, '.parquet'))) %>%
#   filter(level==lv)
df.date <- as.data.frame(read_parquet(paste0('results/hex_time_series/', gp, '_', lv, '.parquet')))
# Create a new column with month and day only
df.date$date <- as.Date(df.date$date)
df.date$month_day <- format(df.date$date, "%m-%d")  # Extract month and day as "MM-DD"
v_lines1 <- data.frame(
  xintercept = c('06-01', '06-01', '09-01', '09-01'),
  year = c(2022, 2022, 2022, 2022)
)
v_lines2 <- data.frame(
  xintercept = c('05-02', '05-02'),
  year = c(2023, 2023)
)
# Add 'policy' column based on conditions
# df.date.9et <- df.date %>%
#   mutate(policy = case_when(
#     (year %in% c(2019, 2022) & month %in% c(5, 6, 7, 8)) ~ "9et",
#     TRUE ~ "other"
#   )) %>%
#   filter(policy=='9et')
#
# df.date.dt <- df.date %>%
#   mutate(policy = case_when(
#     (year %in% c(2022, 2023) & month %in% c(2, 3, 4, 5)) ~ "dt",
#     TRUE ~ "other"
#   )) %>%
#   filter(policy=='dt')

df.date.9et <- df.date %>%
  filter(policy=='9et') %>%
  mutate(policy_status = ifelse(year == 2019, "Baseline (2019)", "Policy (2022)"))

df.date.dt <- df.date %>%
  filter(policy=='dt') %>%
  filter(month > 2) %>%
  mutate(policy_status = ifelse(year == 2022, "Baseline (2022)", "Policy (2023)"))

# Main text ----
g1 <- ggplot(data = df.date.9et,
              aes(x = month_day, y = visit_50,
                  group=policy_status, color = policy_status)) +
  annotate("rect", xmin = '06-01', xmax = '09-01',
           ymin = -Inf, ymax = Inf, alpha = 0.1, fill = "blue") +
  theme_hc() +
  geom_line(size=0.7, alpha=1) +
  scale_color_jama(name='Policy status') +
#  geom_vline(data = v_lines1, aes(xintercept = xintercept),
#         linetype = "dashed", color = "blue", size=0.5, alpha=0.1) +
  # Labels and theme adjustments
  labs(x = "Date", y = "No. of visits") +
  ylim(16, 103) +
  scale_x_discrete(breaks = c("02-01", "03-01", "04-01",
                              "05-02", "06-01", "07-01",
                              "08-01", "09-01"),
  labels = c("Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep")) +  # Adjust x-axis labels if needed
  theme(panel.grid = element_blank(), strip.background = element_blank())

g2 <- ggplot(data = df.date.dt,
              aes(x = month_day, y = visit_50,
                  group=policy_status, color = policy_status)) +
  annotate("rect", xmin = '05-02', xmax = '05-31',
         ymin = -Inf, ymax = Inf, alpha = 0.1, fill = "blue") +
  theme_hc() +
  geom_line(size=0.7, alpha=1) +
  scale_color_jama(name='Policy status') +
#  geom_vline(data = v_lines2, aes(xintercept = xintercept),
#         linetype = "dashed", color = "gray", size=0.5) +
  ylim(30, 80) +
  # Labels and theme adjustments
  labs(x = "Date", y = "No. of visits") +
  scale_x_discrete(breaks = c("02-01", "03-01", "04-01",
                              "05-02", "06-01", "07-01",
                              "08-01", "09-01"),
  labels = c("Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep")) +  # Adjust x-axis labels if needed
  theme(panel.grid = element_blank(), strip.background = element_blank())

g3 <- ggplot(data = df.date.9et,
              aes(x = month_day, y = d_50,
                  group=policy_status, color = policy_status)) +
  annotate("rect", xmin = '06-01', xmax = '09-01',
         ymin = -Inf, ymax = Inf, alpha = 0.1, fill = "blue") +
  theme_hc() +
  geom_line(size=0.7, alpha=1) +
  scale_color_jama(name='Policy status') +
#  geom_vline(data = v_lines1, aes(xintercept = xintercept),
#         linetype = "dashed", color = "gray", size=0.5) +
  ylim(4, 13) +
  # Labels and theme adjustments
  labs(x = "Date", y = "Distance from home (km)") +
  scale_x_discrete(breaks = c("02-01", "03-01", "04-01",
                              "05-02", "06-01", "07-01",
                              "08-01", "09-01"),
  labels = c("Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep")) +  # Adjust x-axis labels if needed
  theme(panel.grid = element_blank(), strip.background = element_blank())

g4 <- ggplot(data = df.date.dt,
              aes(x = month_day, y = d_50,
                  group=policy_status, color = policy_status)) +
  annotate("rect", xmin = '05-02', xmax = '05-31',
       ymin = -Inf, ymax = Inf, alpha = 0.1, fill = "blue") +
  theme_hc() +
  geom_line(size=0.7, alpha=1) +
  scale_color_jama(name='Policy status') +
#  geom_vline(data = v_lines2, aes(xintercept = xintercept),
#         linetype = "dashed", color = "gray", size=0.5) +
  ylim(4, 18.5) +
  # Labels and theme adjustments
  labs(x = "Date", y = "Distance from home (km)") +
  scale_x_discrete(breaks = c("02-01", "03-01", "04-01",
                              "05-02", "06-01", "07-01",
                              "08-01", "09-01"),
  labels = c("Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep")) +  # Adjust x-axis labels if needed
  theme(panel.grid = element_blank(), strip.background = element_blank())

G <- ggarrange(g1, g2, g3, g4, ncol = 2, nrow = 2, labels = c('a', 'b', 'c', 'd'))
ggsave(filename = paste0("figures/manuscript/hex_time_series_", gp, '_', lv, ".png"),
       plot=G, width = 12, height = 7, unit = "in", dpi = 300, bg = 'white')

# Appendix ----
g31 <- ggplot(data = df.date.9et,
              aes(x = month_day, y = visit_50, group=as.factor(year))) +
  theme_hc() +
  geom_line(size=0.5) +
  geom_ribbon(aes(ymin = visit_25, ymax = visit_75), alpha = 0.2, fill='gray') +
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
                              "08-01", "09-01"),
  labels = c("Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep")) +  # Adjust x-axis labels if needed
  theme(panel.grid = element_blank(), strip.background = element_blank())

g32 <- ggplot(data = df.date.9et,
              aes(x = month_day, y = d_50, group=as.factor(year))) +
  theme_hc() +
  geom_line(size=0.5) +
  geom_ribbon(aes(ymin = d_25, ymax = d_75), alpha = 0.2, fill='gray') +
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
                              "08-01", "09-01"),
  labels = c("Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep")) +  # Adjust x-axis labels if needed
  theme(panel.grid = element_blank(), strip.background = element_blank())

g33 <- ggplot(data = df.date.dt,
              aes(x = month_day, y = visit_50, group=as.factor(year))) +
  theme_hc() +
  geom_line(size=0.5) +
  geom_ribbon(aes(ymin = visit_25, ymax = visit_75), alpha = 0.2, fill='gray') +
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

g34 <- ggplot(data = df.date.dt,
              aes(x = month_day, y = d_50, group=as.factor(year))) +
  theme_hc() +
  geom_line(size=0.5) +
  geom_ribbon(aes(ymin = d_25, ymax = d_75), alpha = 0.2, fill='gray') +
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
ggsave(filename = paste0("figures/manuscript/hex_distance_time_series_", gp, '_', lv, ".png"),
       plot=G3, width = 12, height = 7, unit = "in", dpi = 300, bg = 'white')
