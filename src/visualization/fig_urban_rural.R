library(patchwork)
library(data.table)


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



df_urban <- fread('results/tdid/model_results_re_urban.csv')
df_nurban <- fread('results/tdid/model_results_re_nurban.csv')

df_urban$region <- 'Urban'
df_nurban$region <- 'Not-urban'


df <- rbind(df_urban, df_nurban)

df$pvalue <- round(df$pvalue, 2)

df <- df %>%
  mutate(sig = case_when(
    pvalue <= 0.01 ~ "***",  # Highly significant
    pvalue <= 0.05 ~ "**",   # Significant
    pvalue <= 0.1  ~ "*",    # Marginally significant
    TRUE ~ ""                # Not significant
  ))


df <- df %>%
  filter(policy == 'dt') %>%
  filter(variable %in% c('P_m11', 'P_m12', 'P_m13',
                         'P_m21', 'P_m22', 'P_m23',
                         'P_m31', 'P_m32', 'P_m33')) %>%
  mutate(
    # Extracting the first group number (f_grp)
    f_grp = as.integer(sub("P_m(\\d)(\\d)", "\\1", variable)),
    f_grp = factor(f_grp, levels=c(1, 2, 3), labels = c('Q1', 'Q2-Q3', 'Q4')),
    
    # Extracting the second group number (r_grp)
    r_grp = as.integer(sub("P_m(\\d)(\\d)", "\\2", variable)),
    r_grp = factor(r_grp, levels=c(1, 2, 3), labels = c('Q1', 'Q2-Q3', 'Q4'))
  )


# df_visits <- subset(df, var=='num_visits_wt')
# df_distance <- subset(df, var=='d_ha_wt')


df1 <- subset(df, f_grp == "Q1")
df4 <- subset(df, f_grp == "Q4")

ddddd <- subset(df, f_grp %in% c("Q1", "Q4"))


for (thr in c('3', '4', '5', '6')){

  df_visits <- ddddd %>%
      filter(grp == paste0("fr_grp_v_thr_", thr)) %>%
      filter(var == 'num_visits_wt')
  
  df_dist <- ddddd %>%
    filter(grp == paste0("fr_grp_v_thr_", thr)) %>%
    filter(var == 'd_ha_wt')
  
  min_y <- min(df_visits$lower, df_dist$lower)
  max_y <- max(df_visits$upper, df_dist$upper)

  fig_visits <- ggplot(data = df_visits, aes(x=r_grp)) +
    theme_hc() +
    # geom_vline(aes(xintercept = 0), color='gray', size=0.3, show.legend = F) +
    geom_errorbar(aes(ymin=lower, ymax=upper, color=as.factor(region)),
                  width=0.3, linewidth=0.5,
                  position = position_dodge(.7)) +
    geom_point(aes(y=coefficient, color=as.factor(region)), position = position_dodge(.7),
               size=1.3) +
    scale_color_npg(name='Region',
                    breaks=c('Urban', 'Not-urban'),
                    labels = c('Urban', 'Not-urban')) +
    # Add significance markers
    geom_text(
      aes(
        x = r_grp,
        y = upper + 0.05,
        label = sig,
        color=as.factor(region)
      ),
      position = position_dodge(0.7),
      size = 3,
      vjust = 0,
      show.legend = F
    ) +
    ylim(min_y, max_y) +
    facet_wrap(.~f_grp, ncol = 2) +
    labs(subtitle = 'Foreigner share (visitors)',
         x = "Income quantile group (visitors)", y = "Policy effect on visits (%)") +
    theme(strip.background = element_blank(), legend.position = 'bottom')
  
  
  fig_dist <- ggplot(data = df_dist, aes(x=r_grp)) +
    theme_hc() +
    # geom_vline(aes(xintercept = 0), color='gray', size=0.3, show.legend = F) +
    geom_errorbar(aes(ymin=lower, ymax=upper, color=as.factor(region)),
                  width=0.3, linewidth=0.5,
                  position = position_dodge(.7)) +
    geom_point(aes(y=coefficient, color=as.factor(region)), position = position_dodge(.7),
               size=1.3) +
    scale_color_npg(name='Region',
                    breaks=c('Urban', 'Not-urban'),
                    labels = c('Urban', 'Not-urban')) +
    # Add significance markers
    geom_text(
      aes(
        x = r_grp,
        y = upper + 0.05,
        label = sig,
        color=as.factor(region)
      ),
      position = position_dodge(0.7),
      size = 3,
      vjust = 0,
      show.legend = F
    ) +
    ylim(min_y, max_y) +
    facet_wrap(.~f_grp, ncol = 2) +
    labs(subtitle = 'Foreigner share (visitors)',
         x = "Income quantile group (visitors)", y = "Policy effect on travel distances (%)") +
    theme(strip.background = element_blank(), legend.position = 'bottom')
  
  # fig_visits
  # fig_dist
  
  
  # fig_c <- fig_visits / fig_dist +
  #   plot_annotation(tag_levels = '') +
  #   plot_layout(guides = "collect") + #axis_titles = "collect_x",
  #   theme(legend.position = "bottom")
  
  G <- ggarrange(fig_visits, fig_dist, nrow = 2, ncol = 1, labels = c('a', 'b'), common.legend = T)
  ggsave(filename = paste0("figures/fig_C_pop_grps_thr", thr, ".png"),
         plot=G, width = 12, height = 8, unit = "in", dpi = 300, bg = 'white')
}
