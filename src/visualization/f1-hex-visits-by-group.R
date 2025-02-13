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

df.date.9et <- df.date %>%
  filter(policy=='9et') %>%
  filter(month > 5) %>%
  mutate(policy_status = ifelse(year == 2019, "Control (2019)", "Treatment (2022)")) %>%
  mutate(fare_reduction = ifelse((year == 2022) & (month %in% c(6,7,8)),
                     "w/ fare reduction", "w/o fare reduction"))

df.date.dt <- df.date %>%
  filter(policy=='dt') %>%
  filter(month > 2) %>%
  mutate(policy_status = ifelse(year == 2022, "Control (2022)", "Treatment (2023)")) %>%
  mutate(fare_reduction = ifelse((year == 2023) & (month == 5),
                   "w/ fare reduction", "w/o fare reduction"))

# Main text ----
time.series.plot <- function(data, policy, var, yl1, yl2){
  if (policy == '9et'){
    xm <- '06-01'
    xma <- '09-01'
    linet <- c("Control (2019)" = "dashed", "Treatment (2022)" = "solid")
  } else {
    xm <- '05-02'
    xma <- '05-31'
    linet <- c("Control (2022)" = "dashed", "Treatment (2023)" = "solid")
  }
  if (var=='visit'){
    y2plot <- 'visit_50'
    ylb <- 'No. of visits'
  } else {
    y2plot <- 'd_50'
    ylb <- "Distance from home (km)"
  }
  g1 <- ggplot(data = data,
              aes_string(x = 'month_day', y = y2plot, group='policy_status')) +
  annotate("rect", xmin = xm, xmax = xma,
           ymin = -Inf, ymax = Inf, alpha = 0.1, fill = "blue") +
  theme_hc() +
  geom_line(aes_string(linetype = 'policy_status'), size=0.7, alpha=1, color='#402106') +
  scale_linetype_manual(name='Period',
                        values = linet) +
  geom_line(data = data[data$fare_reduction == "w/ fare reduction", ],
            aes_string(x = 'month_day', y = y2plot, group='policy_status'),
            color='#d87414', size=0.7, alpha=1, linetype='solid', inherit.aes = FALSE) +
  labs(x = "Date", y = ylb) +
  ylim(yl1, yl2) +
  scale_x_discrete(breaks = c("02-01", "03-01", "04-01",
                              "05-02", "06-01", "07-01",
                              "08-01", "09-01"),
  labels = c("Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep")) +  # Adjust x-axis labels if needed
  theme(panel.grid = element_blank(), strip.background = element_blank())
  return(g1)
}


# DOW results
df.dow <- as.data.frame(read_parquet(paste0('results/hex_time_series/', gp, '_', lv, '_dow.parquet')))
df.dow$weekday <- factor(df.dow$weekday, levels=seq(0, 6),
                            labels=c('Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'))

df.dow.9et <- df.dow %>%
  filter(policy=='9et') %>%
  mutate(policy_status = ifelse(year == 2019, "Control (2019)", "Treatment (2022)"))

df.dow.dt <- df.dow %>%
  filter(policy=='dt') %>%
  mutate(policy_status = ifelse(year == 2022, "Control (2022)", "Treatment (2023)"))

time.series.dow.plot <- function(data, var, policy){
  if (policy == '9et'){
    brks <- c('Jun-Aug', 'Sep')
    cvalues <- c('blue', '#402106')
  } else {
    brks <- c('Mar-Apr', 'May')
    cvalues <- c('#402106', 'blue')
  }
  if (var=='visit'){
    y2plot <- 'visit'
    ylb <- 'No. of visits'
  } else {
    y2plot <- 'd'
    ylb <- "Distance from home (km)"
  }
  g0 <- ggplot(data = data, aes_string(x='weekday', color='policy_m')) +
    theme_hc() +
    geom_errorbar(aes_string(ymin=paste0(y2plot, '_25'), ymax=paste0(y2plot, '_75')),
                  width=0.3, linewidth=0.5,
                  position = position_dodge(.7), show.legend = T) +
    geom_point(aes_string(y=paste0(y2plot, '_50')), position = position_dodge(.7),
               size=1.3, show.legend = T) +
    facet_wrap(.~policy_status, ncol = 2) +
    scale_color_manual(name='Time', breaks = brks, values = cvalues) +
    labs(x = "", y = ylb) +
    theme(strip.background = element_blank())
  return(g0)
}

g1 <- time.series.plot(data=df.date.9et, policy='9et', var='visit', yl1=16, yl2=103)
g11 <- time.series.dow.plot(data=df.dow.9et, var='visit', policy = '9et')
g2 <- time.series.plot(data=df.date.dt, policy='dt', var='visit', yl1=30, yl2=80)
g21 <- time.series.dow.plot(data=df.dow.dt, var='visit', policy = 'dt')
g3 <- time.series.plot(data=df.date.9et, policy='9et', var='distance', yl1=4, yl2=13)
g31 <- time.series.dow.plot(data=df.dow.9et, var='distance', policy = '9et')
g4 <- time.series.plot(data=df.date.dt, policy='dt', var='distance', yl1=4, yl2=18.5)
g41 <- time.series.dow.plot(data=df.dow.dt, var='distance', policy = 'dt')
G <- ggarrange(g1, g11,
               g2, g21,
               g3, g31,
               g4, g41,
               ncol = 2, nrow = 4, labels = c('a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'))
ggsave(filename = paste0("figures/manuscript/hex_time_series_", gp, '_', lv, ".png"),
       plot=G, width = 13, height = 14, unit = "in", dpi = 300, bg = 'white')

G <- ggarrange(g1, g2, g3, g4, ncol = 2, nrow = 2, labels = c('a', 'b', 'c', 'd'))
ggsave(filename = paste0("figures/manuscript/hex_time_series_", gp, '_', lv, ".png"),
       plot=G, width = 13, height = 7, unit = "in", dpi = 300, bg = 'white')

G <- ggarrange(g2, g4, ncol = 2, nrow = 1, labels = c('a', 'b'), common.legend = T)
ggsave(filename = paste0("figures/manuscript/hex_time_series_", gp, '_', lv, ".png"),
       plot=G, width = 13, height = 4, unit = "in", dpi = 300, bg = 'white')