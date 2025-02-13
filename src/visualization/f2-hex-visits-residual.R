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

gp <- 'all'
lv <- 'all'
df.date <- as.data.frame(read_parquet(paste0('results/hex_time_series/regression_residuals.parquet')))
# Create a new column with month and day only
df.date$date <- as.Date(df.date$date)
df.date$month_day <- format(df.date$date, "%m-%d")  # Extract month and day as "MM-DD"
df.date$year <- format(df.date$date, "%Y")  # Extract year as "YYYY"
v_lines1 <- data.frame(
  xintercept = c('06-01', '06-01', '09-01', '09-01'),
  year = c(2022, 2022, 2022, 2022)
)
v_lines2 <- data.frame(
  xintercept = c('05-02', '05-02'),
  year = c(2023, 2023)
)

df.date.9et <- df.date %>%
  filter(policy=='9ET') %>%
  mutate(policy_status = ifelse(year == 2019, "Control (2019)", "Treatment (2022)"))

df.date.dt <- df.date %>%
  filter(policy=='DT') %>%
  mutate(policy_status = ifelse(year == 2022, "Control (2022)", "Treatment (2023)"))

linet.dt <- c("Control (2022)" = "dashed", "Treatment (2023)" = "solid")
linet.9et <- c("Control (2019)" = "dashed", "Treatment (2022)" = "solid")

# Main text ----
g1 <- ggplot(data = df.date.9et[df.date.9et$var == 'visit',],
              aes(x = month_day, y = res,
                  group=policy_status, linetype = policy_status)) +
  annotate("rect", xmin = '06-01', xmax = '09-01',
           ymin = -Inf, ymax = Inf, alpha = 0.1, fill = "blue") +
  theme_hc() +
  geom_line(size=0.7, alpha=1) +
  scale_linetype_manual(name='Group', values = linet.9et) +
  labs(x = "Date", y = "No. of visits") +
  ylim(-0.4, 0.4) +
  scale_x_discrete(breaks = c("02-01", "03-01", "04-01",
                              "05-02", "06-01", "07-01",
                              "08-01", "09-01"),
  labels = c("Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep")) +  # Adjust x-axis labels if needed
  theme(panel.grid = element_blank(), strip.background = element_blank())

g2 <- ggplot(data = df.date.dt[df.date.dt$var == 'visit',],
              aes(x = month_day, y = res,
                  group=policy_status, linetype = policy_status)) +
  annotate("rect", xmin = '05-02', xmax = '05-31',
         ymin = -Inf, ymax = Inf, alpha = 0.1, fill = "blue") +
  theme_hc() +
  geom_line(size=0.7, alpha=1) +
  scale_linetype_manual(name='Group', values = linet.dt) +
  ylim(-0.4, 0.4) +
  # Labels and theme adjustments
  labs(x = "Date", y = "No. of visits") +
  scale_x_discrete(breaks = c("02-01", "03-01", "04-01",
                              "05-02", "06-01", "07-01",
                              "08-01", "09-01"),
  labels = c("Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep")) +  # Adjust x-axis labels if needed
  theme(panel.grid = element_blank(), strip.background = element_blank())
g2
g3 <- ggplot(data = df.date.9et[df.date.9et$var == 'distance',],
              aes(x = month_day, y = res,
                  group=policy_status, linetype = policy_status)) +
  annotate("rect", xmin = '06-01', xmax = '09-01',
         ymin = -Inf, ymax = Inf, alpha = 0.1, fill = "blue") +
  theme_hc() +
  geom_line(size=0.7, alpha=1) +
  scale_linetype_manual(name='Group', values = linet.9et) +
  ylim(-0.4, 0.4) +
  # Labels and theme adjustments
  labs(x = "Date", y = "Distance from home (km)") +
  scale_x_discrete(breaks = c("02-01", "03-01", "04-01",
                              "05-02", "06-01", "07-01",
                              "08-01", "09-01"),
  labels = c("Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep")) +  # Adjust x-axis labels if needed
  theme(panel.grid = element_blank(), strip.background = element_blank())

g4 <- ggplot(data = df.date.dt[df.date.dt$var == 'distance',],
              aes(x = month_day, y = res,
                  group=policy_status, linetype = policy_status)) +
  annotate("rect", xmin = '05-02', xmax = '05-31',
       ymin = -Inf, ymax = Inf, alpha = 0.1, fill = "blue") +
  theme_hc() +
  geom_line(size=0.7, alpha=1) +
  scale_linetype_manual(name='Group', values = linet.dt) +
  ylim(-0.4, 0.4) +
  # Labels and theme adjustments
  labs(x = "Date", y = "Distance from home (km)") +
  scale_x_discrete(breaks = c("02-01", "03-01", "04-01",
                              "05-02", "06-01", "07-01",
                              "08-01", "09-01"),
  labels = c("Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep")) +  # Adjust x-axis labels if needed
  theme(panel.grid = element_blank(), strip.background = element_blank())
g4
G <- ggarrange(g1, g2, g3, g4, ncol = 2, nrow = 2, labels = c('a', 'b', 'c', 'd'))
ggsave(filename = paste0("figures/manuscript/hex_time_series_", gp, '_', lv, "_res.png"),
       plot=G, width = 12, height = 7, unit = "in", dpi = 300, bg = 'white')
