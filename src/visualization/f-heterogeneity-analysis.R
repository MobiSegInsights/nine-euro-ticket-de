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
df$pvalue <- round(df$pvalue, 2)
df <- df %>%
  mutate(sig = case_when(
    pvalue <= 0.01 ~ "***",  # Highly significant
    pvalue <= 0.05 ~ "**",   # Significant
    pvalue <= 0.1  ~ "*",    # Marginally significant
    TRUE ~ ""                # Not significant
  ))

# Weekday vs. weekend ----
df.dow.wk <- df %>%
  filter(grp=='all_weekday') %>%
  filter(variable %in% c('P_m')) %>%
  # filter(pvalue < 0.05) %>%
  mutate(grp='Weekday')

df.dow.wkd <- df %>%
  filter(grp=='all_weekend') %>%
  filter(variable %in% c('P_m')) %>%
  # filter(pvalue < 0.05) %>%
  mutate(grp='Weekend')

df.dow <- rbind(df.dow.wk, df.dow.wkd)

df.dow$var <- factor(df.dow$var,
                         levels=c('num_visits_wt', 'd_ha_wt'),
                         labels=c('No. of visits', 'Distance from home'))

g0 <- ggplot(data = df.dow, aes(x=grp)) +
  theme_hc() +
  # geom_vline(aes(xintercept = 0), color='gray', size=0.3, show.legend = F) +
  geom_errorbar(aes(ymin=lower, ymax=upper, color=as.factor(policy)),
                width=0.3, linewidth=0.5,
                position = position_dodge(.7), show.legend = T) +
  geom_point(aes(y=coefficient, color=as.factor(policy)), position = position_dodge(.7),
             size=1.3, show.legend = T) +
  scale_color_npg(name='Policy', breaks=c(1, 2), labels = c('9ET', 'DT')) +
  # Add significance markers
  geom_text(
    aes(
      x = grp,
      y = upper + 0.05,
      label = sig,
      color=as.factor(policy)
    ),
    position = position_dodge(0.7),
    size = 3,
    vjust = 0,
    show.legend = F
  ) +
  facet_wrap(.~var, ncol = 2) +
  labs(x = "", y = "Policy effect (%)") +
  theme(strip.background = element_blank())

ggsave(filename = paste0("figures/manuscript/dow_grps.png"),
       plot=g0, width = 9, height = 6, unit = "in", dpi = 300, bg = 'white')

# PT access group ----
df.pt <- df %>%
  filter(grp=='pt_grp') %>%
  filter(variable %in% c('P_m1', 'P_m2', 'P_m3', 'P_m4'))

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
  # Add significance markers
  geom_text(
    aes(
      x = variable,
      y = upper + 0.05,
      label = sig,
      color=as.factor(policy)
    ),
    position = position_dodge(0.7),
    size = 3,
    vjust = 0,
    show.legend = F
  ) +
  facet_wrap(.~var, ncol = 2) +
  labs(x = "Public transit access group", y = "Policy effect (%)") +
  theme(strip.background = element_blank())

ggsave(filename = paste0("figures/manuscript/pt_grps.png"),
       plot=g1, width = 9, height = 6, unit = "in", dpi = 300, bg = 'white')

# Activity type by clusters ----
df.act.c <- df %>%
  filter(grp %in% c("cluster")) %>%
  filter(variable %in% c('P_m1', 'P_m2', 'P_m3', 'P_m4'))

df.act.c$var <- factor(df.act.c$var,
                         levels=c('num_visits_wt', 'd_ha_wt'),
                         labels=c('No. of visits', 'Distance from home'))

df.act.c$variable <- factor(df.act.c$variable,
                         levels=c('P_m1', 'P_m2', 'P_m3', 'P_m4'),
                         labels=c('Low-activity area', 'Recreational area', 'Balanced mix', 'High-activity hub'))

g4 <- ggplot(data = df.act.c, aes(x=variable)) +
  theme_hc() +
  geom_errorbar(aes(ymin=lower, ymax=upper, color=as.factor(policy)),
                width=0.3, linewidth=0.5,
                position = position_dodge(.7), show.legend = T) +
  geom_point(aes(y=coefficient, color=as.factor(policy)), position = position_dodge(.7),
             size=1.3, show.legend = T) +
  scale_color_npg(name='Policy', breaks=c(1, 2), labels = c('9ET', 'DT')) +
  # Add significance markers
  geom_text(
    aes(
      x = variable,
      y = upper + 10,
      label = sig,
      color=as.factor(policy)
    ),
    position = position_dodge(0.7),
    size = 3,
    vjust = 0,
    angle = 90,
    show.legend = F
  ) +
  facet_wrap(.~var, scales="free_x") +
  labs(x = "", y = "Policy effect (%)") +
  theme(strip.background = element_blank()) +
  coord_flip()
ggsave(filename = paste0("figures/manuscript/activity_type_cluster_grps.png"),
       plot=g4, width = 9, height = 6, unit = "in", dpi = 300, bg = 'white')

# Population groups ----
df.pop <- df %>%
  filter(grp %in% c("f_grp", "r_grp")) %>%
  filter(variable %in% c('P_m1', 'P_m2', 'P_m3', 'P_m4'))

df.pop$var <- factor(df.pop$var,
                         levels=c('num_visits_wt', 'd_ha_wt'),
                         labels=c('No. of visits', 'Distance from home'))

df.pop$variable <- factor(df.pop$variable,
                         levels=c('P_m1', 'P_m2', 'P_m3', 'P_m4'),
                         labels=c('Q1', 'Q2', 'Q3', 'Q4'))

df.pop$grp <- factor(df.pop$grp,
                     levels=c("f_grp", "r_grp"),
                     labels=c('Foreigner share', "Net rent level"))

g3 <- ggplot(data = df.pop, aes(x=variable)) +
  theme_hc() +
  # geom_vline(aes(xintercept = 0), color='gray', size=0.3, show.legend = F) +
  geom_errorbar(aes(ymin=lower, ymax=upper, color=as.factor(policy)),
                width=0.3, linewidth=0.5,
                position = position_dodge(.7), show.legend = T) +
  geom_point(aes(y=coefficient, color=as.factor(policy)), position = position_dodge(.7),
             size=1.3, show.legend = T) +
  scale_color_npg(name='Policy', breaks=c(1, 2), labels = c('9ET', 'DT')) +
  # Add significance markers
  geom_text(
    aes(
      x = variable,
      y = upper + 0.05,
      label = sig,
      color=as.factor(policy)
    ),
    position = position_dodge(0.7),
    size = 3,
    vjust = 0,
    show.legend = F
  ) +
  facet_wrap(grp~var, ncol = 4) +
  labs(x = "Population quantile group", y = "Policy effect (%)") +
  theme(strip.background = element_blank())

ggsave(filename = paste0("figures/manuscript/pop_grps.png"),
       plot=g3, width = 12, height = 6, unit = "in", dpi = 300, bg = 'white')