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
variable <- 'net_rent_v'
df.date <- as.data.frame(read_parquet(paste0('results/hex_time_series/', gp, '_', lv, '_', variable, '.parquet')))
# Create a new column with month and day only
df.date$date <- as.Date(df.date$date)
df.date$month_day <- format(df.date$date, "%m-%d")  # Extract month and day as "MM-DD"
v_lines2 <- data.frame(
  xintercept = c('05-02', '05-02'),
  year = c(2023, 2023)
)

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
  if (var=='f_share_v'){
    y2plot <- 'f_share_v_50'
    ylb <- 'Share of foreigners (visitors)'
  } else {
    y2plot <- 'net_rent_v_50'
    ylb <- "Net rent (visitors)"
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

g1 <- time.series.plot(data=df.date.dt, policy='dt', var=variable, yl1=6.1, yl2=6.4)
ggsave(filename = paste0("figures/manuscript/hex_time_series_", gp, '_', lv, '_', variable, ".png"),
       plot=g1, width = 12, height = 4, unit = "in", dpi = 300, bg = 'white')
