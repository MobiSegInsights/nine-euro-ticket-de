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
library(magick)
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

# DiD Model 2 Full 2022 vs. 2023 (Jun-Aug) by PT access ----
df <- as.data.frame(read_parquet('results/did/all_states_model_v5_pt3_pois_6_8_by_pt.parquet'))
df <- df %>%
  mutate(lower = parameter-ci) %>%
  mutate(upper = parameter+ci) %>%
  filter(y %in% c('P_m1', 'P_m2', 'P_m3', 'P_m4'))

df$y <- factor(df$y, levels = c('P_m1', 'P_m2', 'P_m3', 'P_m4'),
               labels = c('3-14', '14-24', '24-37', '>37'))

g4 <- ggplot(data = df, aes(x=y, y=parameter)) +
    theme_hc() +
    geom_linerange(aes(ymin=lower, ymax=upper),
                   size=1, alpha=1, color='darkblue') +
    geom_point(shape = 21, fill = "white", size = 2, color='darkblue') +
    labs(x = 'No. of nearby public transit\n stations (< 800 m)',
         y = 'Change in no. of daily visits') +
    theme(strip.background = element_blank()) +
  coord_flip()
ggsave(filename = paste0("figures/did/did_model_pt.png"),
       plot=g4, width = 4, height = 3, unit = "in", dpi = 300, bg = 'white')

df.poi <- as.data.frame(read_parquet('results/did/all_states_model_v5_pt3_pois_stats.parquet'))
df.poi <- arrange(df.poi, year, period, -num_visits_wt)
df.poi$period <- factor(df.poi$period, levels = c(1, 0),
               labels = c('May', 'Jun-Aug'))

g5 <- ggplot(data = df.poi, aes(x=num_visits_wt, y=reorder(label, num_visits_wt, FUN = median),
                                color=as.factor(year), shape=period)) +
  geom_point(fill = "white", size = 2) +
    theme_hc() +
  scale_color_manual(name='Year',
                       breaks = c(2022, 2023),
                       values = c('darkblue', 'darkred'),
    ) +
    scale_shape_manual(name='Period',
                       breaks = c('May', 'Jun-Aug'),
                       values = c(1, 3),
    ) +
    labs(x = '% visits by place type',
         y = 'Place type') +
    guides(color=guide_legend(nrow=1,byrow=TRUE),
           shape=guide_legend(nrow=1,byrow=TRUE)) +
    theme(strip.background = element_blank(),
          legend.position=c(.6,.2),
    legend.background = element_blank())

df.poi.ef <- as.data.frame(read_parquet('results/did/all_states_model_v5_pt3_pois_6_8_by_poi.parquet'))
df.poi.ef <- df.poi.ef %>%
  filter(grepl("^P_m_", y)) %>%
  filter(pvalue < 0.05) %>%
  mutate(y = sub("^P_m_", "", y)) %>%
  mutate(lower = parameter-ci) %>%
  mutate(upper = parameter+ci)

g6 <- ggplot(data = df.poi.ef, aes(x=reorder(y, parameter), y=parameter)) +
    theme_hc() +
    geom_linerange(aes(ymin=lower, ymax=upper),
                   size=1, alpha=1, color='darkblue') +
    geom_point(shape = 21, fill = "white", size = 2, color='darkblue') +
    labs(x = 'Place type',
         y = 'Change in no. of daily visits') +
    theme(strip.background = element_blank()) +
  coord_flip()

G <- ggarrange(g5, g6, ncol = 2, nrow = 1, labels = c('c', 'd'))
ggsave(filename = paste0("figures/did/did_model_poi.png"),
       plot=G, width = 8, height = 5, unit = "in", dpi = 300, bg = 'white')

# Create figure panel ----
# ----- Combine labeled images -------
# Load the two input .png images
read.img <- function(path, lb){
  image <- image_read(path) %>%
    image_annotate(lb, gravity = "northwest", color = "black", size = 55, weight = 700)
  return(image)
}
# image1 <- read.img(path="figures/did/did_model.png", lb='a')
image2 <- read.img(path="figures/did/did_model_pt.png", lb='b')
image3 <- read.img(path="figures/did/did_model_poi.png", lb=' ')

## Combine images 1-2
# Get height of image 1
image2_width <- image_info(image2)$width
image1_resized <- image_resize(image_read("figures/did/did_model.png"),
                               paste0(image2_width, "x")) %>%
    image_annotate('a', gravity = "northwest", color = "black", size = 55, weight = 700)
blank_space_w <- image_blank(image2_width, 1, color = "white")

# Create blank space between them and stack three
combined_image1 <- image_append(c(image1_resized, blank_space_w, image2), stack = T)

combined_image1_height <- image_info(combined_image1)$height

# Combine the images side by side
blank_space_h <- image_blank(1, combined_image1_height, color = "white")
combined_image <- image_append(c(combined_image1, blank_space_h, image3), stack = F)
image_write(combined_image, "figures/did/did_model_fig.png")
