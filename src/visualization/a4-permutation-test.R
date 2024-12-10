# Title     : Permutation test results
# Objective : Describe the permutation results
# Created by: Yuan Liao
# Created on: 2024-11-18

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

df <- read.csv('results/tdid/permutation_results_by_state_basic.csv')
# Create a named vector for mapping
mapping <- c("9ET", "DT")
names(mapping) <- c(1, 2)
# Map values using recode
df <- df %>%
  mutate(policy = recode(policy, !!!mapping))

mapping <- c("No. of visits (%)", "Distance from home (%)")
names(mapping) <- c("num_visits_wt", "d_ha_wt")
df <- df %>%
  mutate(var = recode(var, !!!mapping))

# Manuscript ----
g <- ggplot(data=df) +
  geom_point(aes(x=coefficient, y=pvalue), size=0.5, alpha=0.6) +
  facet_wrap(var ~ policy, scales = "free") +
  xlim(-0.006, 0.006) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray", size=0.5) +
  theme_hc() +
  labs(y = "P value", x = expression(Interaction~coefficient~delta)) +
  theme(legend.position = 'bottom',
        plot.title = element_text(hjust = 0, face = "bold"),
        axis.text.x = element_text(angle = 0, vjust = 0.5, hjust=0.5),
        panel.grid = element_blank(), strip.background = element_blank())

ggsave(filename = paste0("figures/manuscript/b_permutation_test.png"),
       plot=g, width = 10, height = 7, unit = "in", dpi = 300, bg = 'white')

# Data exploration ----
h_lines <- data.frame(
  yintercept = c(0.18, -0.19, 0.16, 0.095),
  policy = c('9ET', '9ET', 'DT', 'DT'),
  var = c('Visiting volume', "Distance from home (km)",
          'Visiting volume', "Distance from home (km)")
)

g1 <- ggplot(data=df) +
  geom_point(aes(x=pvalue, y=coefficient), size=0.5, alpha=0.6) +
  facet_wrap(policy ~ var, scales = "free") +
  xlim(-0.001, 1) +
  geom_hline(data = h_lines, aes(yintercept = yintercept),
         linetype = "dashed", color = "#0fbcf9", size=1) +
  theme_hc() +
  labs(x = "P value", y = expression(Coefficient~delta)) +
  theme(legend.position = 'bottom',
        plot.title = element_text(hjust = 0, face = "bold"),
        axis.text.x = element_text(angle = 0, vjust = 0.5, hjust=0.5),
        panel.grid = element_blank(), strip.background = element_blank())


g2 <- ggplot(data=df) +
  geom_point(aes(x=pvalue, y=coefficient), size=0.5, alpha=0.6) +
  facet_wrap(policy ~ var, scales = "free") +
  xlim(-0.001, 1) +
  theme_hc() +
  labs(x = "P value", y = expression(Coefficient~delta)) +
  theme(legend.position = 'bottom',
        plot.title = element_text(hjust = 0, face = "bold"),
        axis.text.x = element_text(angle = 0, vjust = 0.5, hjust=0.5),
        panel.grid = element_blank(), strip.background = element_blank())

G <- ggarrange(g1, g2, ncol = 2, nrow = 1, labels = c('a', 'b'))
ggsave(filename = paste0("figures/manuscript/permutation_test.png"),
       plot=G, width = 12, height = 7, unit = "in", dpi = 300, bg = 'white')
