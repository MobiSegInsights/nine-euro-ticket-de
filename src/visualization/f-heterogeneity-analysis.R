library(dplyr)
library(ggplot2)
library(ggsci)
library(scico)
library(ggthemes)
library(ggpubr)
library(ggdensity)
library(ggmap)
library(ggspatial)
library(arrow)
library(scales)
library(ggExtra)
library(hrbrthemes)
library(magick)
library(boot)
library(sf)

options(scipen=10000)

df <- read.csv('results/tdid/model_results.csv')

# PT access group ----
df.pt <- df %>%
  filter(grp=='pt_grp') %>%
  filter(variable %in% c('P_m1', 'P_m2', 'P_m3', 'P_m4')) %>%
  filter(pvalue < 0.05)

df.pt$var <- factor(df.pt$var,
                         levels=c('num_visits_wt', 'd_ha_wt'),
                         labels=c('No. of visits', 'Distance from home'))

df.pt$variable <- factor(df.pt$variable,
                         levels=c('P_m1', 'P_m2', 'P_m3', 'P_m4'),
                         labels=c('Q1', 'Q2', 'Q3', 'Q4'))

g1 <- ggplot(data = df.pt, aes(x=variable)) +
  theme_hc() +
  # geom_vline(aes(xintercept = 0), color='gray', size=0.3, show.legend = F) +
  geom_errorbar(aes(ymin=lower, ymax=upper, color=as.factor(policy)),
                width=0.3, linewidth=0.5,
                position = position_dodge(.7), show.legend = T) +
  geom_point(aes(y=coefficient, color=as.factor(policy)), position = position_dodge(.7),
             size=1.3, show.legend = T) +
  scale_color_npg(name='Policy', breaks=c(1, 2), labels = c('9ET', 'DT')) +
  facet_wrap(.~var, scales="free", ncol = 4) +
  labs(x = "Public transit access group", y = "Policy effect (%)") +
  theme(strip.background = element_blank())

ggsave(filename = paste0("figures/manuscript/pt_grps.png"),
       plot=g1, width = 9, height = 7, unit = "in", dpi = 300, bg = 'white')

# Activity type ----
df.act <- df %>%
  filter(grp %in% c('Food and drink_grp', "Leisure_grp",
                    "Life_grp", "Tourism_grp", "Wellness_grp")) %>%
  filter(variable %in% c('P_m1', 'P_m2', 'P_m3', 'P_m4')) %>%
  filter(pvalue < 0.05)

df.act$var <- factor(df.act$var,
                         levels=c('num_visits_wt', 'd_ha_wt'),
                         labels=c('No. of visits', 'Distance from home'))

df.act$variable <- factor(df.act$variable,
                         levels=c('P_m1', 'P_m2', 'P_m3', 'P_m4'),
                         labels=c('Q1', 'Q2', 'Q3', 'Q4'))

df.act$grp <- factor(df.act$grp,
                     levels=c('Food and drink_grp', "Leisure_grp",
                              "Life_grp", "Tourism_grp", "Wellness_grp"),
                     labels=c('Food and drink', "Leisure",
                              "Life", "Tourism", "Wellness"))

g21 <- ggplot(data = df.act[df.act$var=='No. of visits',], aes(x=variable)) +
  theme_hc() +
  # geom_vline(aes(xintercept = 0), color='gray', size=0.3, show.legend = F) +
  geom_errorbar(aes(ymin=lower, ymax=upper, color=as.factor(policy)),
                width=0.3, linewidth=0.5,
                position = position_dodge(.7), show.legend = T) +
  geom_point(aes(y=coefficient, color=as.factor(policy)), position = position_dodge(.7),
             size=1.3, show.legend = T) +
  scale_color_npg(name='Policy', breaks=c(1, 2), labels = c('9ET', 'DT')) +
  facet_wrap(.~grp, ncol = 5) +
  labs(x = "", y = "Policy effect (%)") +
  theme(strip.background = element_blank())

g22 <- ggplot(data = df.act[df.act$var=='Distance from home',], aes(x=variable)) +
  theme_hc() +
  # geom_vline(aes(xintercept = 0), color='gray', size=0.3, show.legend = F) +
  geom_errorbar(aes(ymin=lower, ymax=upper, color=as.factor(policy)),
                width=0.3, linewidth=0.5,
                position = position_dodge(.7), show.legend = T) +
  geom_point(aes(y=coefficient, color=as.factor(policy)), position = position_dodge(.7),
             size=1.3, show.legend = T) +
  scale_color_npg(name='Policy', breaks=c(1, 2), labels = c('9ET', 'DT')) +
  facet_wrap(.~grp, ncol = 5) +
  labs(x = "Activity type quantile group", y = "Policy effect (%)") +
  theme(strip.background = element_blank())

g2 <- ggarrange(g21, g22, ncol = 1, nrow = 2, labels = c('a', 'b'), common.legend = T)
ggsave(filename = paste0("figures/manuscript/activity_type_grps.png"),
       plot=g2, width = 12, height = 7, unit = "in", dpi = 300, bg = 'white')

# Activity type by clusters ----
df.act.c <- df %>%
  filter(grp %in% c("cluster")) %>%
  filter(variable %in% c('P_m1', 'P_m2', 'P_m3', 'P_m4', 'P_m5')) %>%
  filter(pvalue < 0.05)

df.act.c$var <- factor(df.act.c$var,
                         levels=c('num_visits_wt', 'd_ha_wt'),
                         labels=c('No. of visits', 'Distance from home'))

df.act.c$variable <- factor(df.act.c$variable,
                         levels=c('P_m1', 'P_m2', 'P_m3', 'P_m4', 'P_m5'),
                         labels=c('Sparse activity cluster', 'Tourism-focused sparse cluster',
                                  'Tourism-Life cluster', 'Residential and dining cluster',
                                  'High-activity hub'))

g4 <- ggplot(data = df.act.c, aes(x=variable)) +
  theme_hc() +
  # geom_vline(aes(xintercept = 0), color='gray', size=0.3, show.legend = F) +
  geom_errorbar(aes(ymin=lower, ymax=upper, color=as.factor(policy)),
                width=0.3, linewidth=0.5,
                position = position_dodge(.7), show.legend = T) +
  geom_point(aes(y=coefficient, color=as.factor(policy)), position = position_dodge(.7),
             size=1.3, show.legend = T) +
  scale_color_npg(name='Policy', breaks=c(1, 2), labels = c('9ET', 'DT')) +
  facet_wrap(.~var, scales="free") +
  labs(x = "", y = "Policy effect (%)") +
  theme(strip.background = element_blank()) +
  coord_flip()
ggsave(filename = paste0("figures/manuscript/activity_type_cluster_grps.png"),
       plot=g4, width = 12, height = 7, unit = "in", dpi = 300, bg = 'white')

# Population groups ----
df.pop <- df %>%
  filter(grp %in% c("f_grp", "g_grp", "r_grp")) %>%
  filter(variable %in% c('P_m1', 'P_m2', 'P_m3', 'P_m4')) %>%
  filter(pvalue < 0.05)

df.pop$var <- factor(df.pop$var,
                         levels=c('num_visits_wt', 'd_ha_wt'),
                         labels=c('No. of visits', 'Distance from home'))

df.pop$variable <- factor(df.pop$variable,
                         levels=c('P_m1', 'P_m2', 'P_m3', 'P_m4'),
                         labels=c('Q1', 'Q2', 'Q3', 'Q4'))

df.pop$grp <- factor(df.pop$grp,
                     levels=c("f_grp", "g_grp", "r_grp"),
                     labels=c('Foreigner share', "Deprivation level",
                              "Net rent level"))

g3 <- ggplot(data = df.pop, aes(x=variable)) +
  theme_hc() +
  # geom_vline(aes(xintercept = 0), color='gray', size=0.3, show.legend = F) +
  geom_errorbar(aes(ymin=lower, ymax=upper, color=as.factor(policy)),
                width=0.3, linewidth=0.5,
                position = position_dodge(.7), show.legend = T) +
  geom_point(aes(y=coefficient, color=as.factor(policy)), position = position_dodge(.7),
             size=1.3, show.legend = T) +
  scale_color_npg(name='Policy', breaks=c(1, 2), labels = c('9ET', 'DT')) +
  facet_wrap(grp~var, scales="free", ncol = 6) +
  labs(x = "Population quantile group", y = "Policy effect (%)") +
  theme(strip.background = element_blank())

ggsave(filename = paste0("figures/manuscript/pop_grps.png"),
       plot=g3, width = 15, height = 5, unit = "in", dpi = 300, bg = 'white')