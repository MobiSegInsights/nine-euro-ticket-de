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
library(biscale)
library(cowplot)
options(scipen=10000)

# Basemaps ----
ggmap::register_stadiamaps(key='1ffbd641-ab9c-448b-8f83-95630d3c7ee3')
z.level <- 11
# Berlin
bbox <- c(12.8609612704,52.2188315508,13.9357904838,52.7999993305)
names(bbox) <- c("left", "bottom", "right", "top")
berlin_basemap <- get_stadiamap(bbox, maptype="stamen_toner_lines", zoom = z.level)

# Hamburg
bbox <- c(9.5944196795,53.3254946513,10.405576934,53.7709899285)
names(bbox) <- c("left", "bottom", "right", "top")
hamburg_basemap <- get_stadiamap(bbox, maptype="stamen_toner_lines", zoom = z.level)

# Munich
bbox <- c(11.1718426327,47.8882900285,11.9756045523,48.3830843127)
names(bbox) <- c("left", "bottom", "right", "top")
munich_basemap <- get_stadiamap(bbox, maptype="stamen_toner_lines", zoom = z.level)

# Cologne
bbox <- c(6.5591869372,50.7046021299,7.3629488568,51.1718079045)
names(bbox) <- c("left", "bottom", "right", "top")
cologne_basemap <- get_stadiamap(bbox, maptype="stamen_toner_lines", zoom = z.level)

# PT access and activity cluster ----
policy <- 'dt'
gdf2 <- st_transform(st_read(paste0("results/tdid/h3_groups_", policy, ".shp")), 4326)
gdf2$pt_grp <- factor(gdf2$pt_grp, levels=c('q1', 'q2', 'q3', 'q4'), labels=c('Q1', 'Q2', 'Q3', 'Q4'))
gdf2$c_name <- factor(gdf2$c_name, levels=c('Low-activity area', 'Recreational area',
                                            'Balanced mix', 'High-activity hub'))

# PT access group ----
g1 <- ggmap(berlin_basemap) +
  geom_sf(data = gdf2[!is.na(gdf2$pt_grp), ], aes(fill=pt_grp),
          color = 'white', size=0.05, alpha=0.7, show.legend = T, inherit.aes = FALSE) +
  labs(title = 'Berlin') +
  scale_fill_locuszoom(name='Public transit group') +
  annotation_scale(location = "bl", width_hint = 0.3, text_cex = 0.5) +  # Add a scale bar
  annotation_north_arrow(
    location = "tr", which_north = "true",
    style = north_arrow_fancy_orienteering(text_size = 6),
    height = unit(0.8, "cm"),  # Adjust arrow height
    width = unit(0.8, "cm")    # Adjust arrow width
  ) +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5)) +
  guides(fill = guide_legend(nrow = 1))

g2 <- ggmap(hamburg_basemap) +
  geom_sf(data = gdf2[!is.na(gdf2$pt_grp), ], aes(fill=pt_grp),
          color = 'white', size=0.05, alpha=0.7, show.legend = T, inherit.aes = FALSE) +
  labs(title = 'Hamburg') +
  scale_fill_locuszoom(name='Public transit group') +
  annotation_scale(location = "bl", width_hint = 0.3, text_cex = 0.5) +  # Add a scale bar
  annotation_north_arrow(
    location = "tr", which_north = "true",
    style = north_arrow_fancy_orienteering(text_size = 6),
    height = unit(0.8, "cm"),  # Adjust arrow height
    width = unit(0.8, "cm")    # Adjust arrow width
  ) +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5)) +
  guides(fill = guide_legend(nrow = 1))

g3 <- ggmap(munich_basemap) +
  geom_sf(data = gdf2[!is.na(gdf2$pt_grp), ], aes(fill=pt_grp),
          color = 'white', size=0.05, alpha=0.7, show.legend = T, inherit.aes = FALSE) +
  labs(title = 'Munich') +
  scale_fill_locuszoom(name='Public transit group') +
  annotation_scale(location = "bl", width_hint = 0.3, text_cex = 0.5) +  # Add a scale bar
  annotation_north_arrow(
    location = "tr", which_north = "true",
    style = north_arrow_fancy_orienteering(text_size = 6),
    height = unit(0.8, "cm"),  # Adjust arrow height
    width = unit(0.8, "cm")    # Adjust arrow width
  ) +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5)) +
  guides(fill = guide_legend(nrow = 1))

g4 <- ggmap(cologne_basemap) +
  geom_sf(data = gdf2[!is.na(gdf2$pt_grp), ], aes(fill=pt_grp),
          color = 'white', size=0.05, alpha=0.7, show.legend = T, inherit.aes = FALSE) +
  labs(title = 'Cologne') +
  scale_fill_locuszoom(name='Public transit group') +
  annotation_scale(location = "bl", width_hint = 0.3, text_cex = 0.5) +  # Add a scale bar
  annotation_north_arrow(
    location = "tr", which_north = "true",
    style = north_arrow_fancy_orienteering(text_size = 6),
    height = unit(0.8, "cm"),  # Adjust arrow height
    width = unit(0.8, "cm")    # Adjust arrow width
  ) +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5)) +
  guides(fill = guide_legend(nrow = 1))

G1 <- ggarrange(g1, g2, g3, g4, ncol = 2, nrow = 2, common.legend = T)
ggsave(filename = paste0("figures/manuscript/pt_grps_maps_", policy, ".png"),
       plot=G1, width = 6, height = 6, unit = "in", dpi = 300, bg = 'white')

# Activity clusters ----
g5 <- ggmap(berlin_basemap) +
  geom_sf(data = gdf2[!is.na(gdf2$c_name), ], aes(fill=c_name),
          color = 'white', size=0.05, alpha=0.7, show.legend = T, inherit.aes = FALSE) +
  labs(title = 'Berlin') +
  scale_fill_locuszoom(name='Activity type group') +
  annotation_scale(location = "bl", width_hint = 0.3, text_cex = 0.5) +  # Add a scale bar
  annotation_north_arrow(
    location = "tr", which_north = "true",
    style = north_arrow_fancy_orienteering(text_size = 6),
    height = unit(0.8, "cm"),  # Adjust arrow height
    width = unit(0.8, "cm")    # Adjust arrow width
  ) +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5)) +
  guides(fill = guide_legend(nrow = 2))

g6 <- ggmap(hamburg_basemap) +
  geom_sf(data = gdf2[!is.na(gdf2$c_name), ], aes(fill=c_name),
          color = 'white', size=0.05, alpha=0.7, show.legend = T, inherit.aes = FALSE) +
  labs(title = 'Hamburg') +
  scale_fill_locuszoom(name='Activity type group') +
  annotation_scale(location = "bl", width_hint = 0.3, text_cex = 0.5) +  # Add a scale bar
  annotation_north_arrow(
    location = "tr", which_north = "true",
    style = north_arrow_fancy_orienteering(text_size = 6),
    height = unit(0.8, "cm"),  # Adjust arrow height
    width = unit(0.8, "cm")    # Adjust arrow width
  ) +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5)) +
  guides(fill = guide_legend(nrow = 2))

g7 <- ggmap(munich_basemap) +
  geom_sf(data = gdf2[!is.na(gdf2$c_name), ], aes(fill=c_name),
          color = 'white', size=0.05, alpha=0.7, show.legend = T, inherit.aes = FALSE) +
  labs(title = 'Munich') +
  scale_fill_locuszoom(name='Activity type group') +
  annotation_scale(location = "bl", width_hint = 0.3, text_cex = 0.5) +  # Add a scale bar
  annotation_north_arrow(
    location = "tr", which_north = "true",
    style = north_arrow_fancy_orienteering(text_size = 6),
    height = unit(0.8, "cm"),  # Adjust arrow height
    width = unit(0.8, "cm")    # Adjust arrow width
  ) +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5)) +
  guides(fill = guide_legend(nrow = 2))

g8 <- ggmap(cologne_basemap) +
  geom_sf(data = gdf2[!is.na(gdf2$c_name), ], aes(fill=c_name),
          color = 'white', size=0.05, alpha=0.7, show.legend = T, inherit.aes = FALSE) +
  labs(title = 'Cologne') +
  scale_fill_locuszoom(name='Activity type group') +
  annotation_scale(location = "bl", width_hint = 0.3, text_cex = 0.5) +  # Add a scale bar
  annotation_north_arrow(
    location = "tr", which_north = "true",
    style = north_arrow_fancy_orienteering(text_size = 6),
    height = unit(0.8, "cm"),  # Adjust arrow height
    width = unit(0.8, "cm")    # Adjust arrow width
  ) +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5)) +
  guides(fill = guide_legend(nrow = 2))

G2 <- ggarrange(g5, g6, g7, g8, ncol = 2, nrow = 2, common.legend = T)
ggsave(filename = paste0("figures/manuscript/activity_type_cluster_grps_maps_", policy, ".png"),
       plot=G2, width = 6, height = 6, unit = "in", dpi = 300, bg = 'white')

# Population groups/Citizenship ----
g9 <- ggmap(berlin_basemap) +
  geom_sf(data = gdf2[!is.na(gdf2$f_grp), ], aes(fill=f_grp),
          color = 'white', size=0.05, alpha=0.7, show.legend = T, inherit.aes = FALSE) +
  labs(title = 'Berlin') +
  scale_fill_locuszoom(name='Foreigner share group') +
  annotation_scale(location = "bl", width_hint = 0.3, text_cex = 0.5) +  # Add a scale bar
  annotation_north_arrow(
    location = "tr", which_north = "true",
    style = north_arrow_fancy_orienteering(text_size = 6),
    height = unit(0.8, "cm"),  # Adjust arrow height
    width = unit(0.8, "cm")    # Adjust arrow width
  ) +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5)) +
  guides(fill = guide_legend(nrow = 1))

g10 <- ggmap(hamburg_basemap) +
  geom_sf(data = gdf2[!is.na(gdf2$f_grp), ], aes(fill=f_grp),
          color = 'white', size=0.05, alpha=0.7, show.legend = T, inherit.aes = FALSE) +
  labs(title = 'Hamburg') +
  scale_fill_locuszoom(name='Foreigner share group') +
  annotation_scale(location = "bl", width_hint = 0.3, text_cex = 0.5) +  # Add a scale bar
  annotation_north_arrow(
    location = "tr", which_north = "true",
    style = north_arrow_fancy_orienteering(text_size = 6),
    height = unit(0.8, "cm"),  # Adjust arrow height
    width = unit(0.8, "cm")    # Adjust arrow width
  ) +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5)) +
  guides(fill = guide_legend(nrow = 1))

g11 <- ggmap(munich_basemap) +
  geom_sf(data = gdf2[!is.na(gdf2$f_grp), ], aes(fill=f_grp),
          color = 'white', size=0.05, alpha=0.7, show.legend = T, inherit.aes = FALSE) +
  labs(title = 'Munich') +
  scale_fill_locuszoom(name='Foreigner share group') +
  annotation_scale(location = "bl", width_hint = 0.3, text_cex = 0.5) +  # Add a scale bar
  annotation_north_arrow(
    location = "tr", which_north = "true",
    style = north_arrow_fancy_orienteering(text_size = 6),
    height = unit(0.8, "cm"),  # Adjust arrow height
    width = unit(0.8, "cm")    # Adjust arrow width
  ) +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5)) +
  guides(fill = guide_legend(nrow = 1))

g12 <- ggmap(cologne_basemap) +
  geom_sf(data = gdf2[!is.na(gdf2$f_grp), ], aes(fill=f_grp),
          color = 'white', size=0.05, alpha=0.7, show.legend = T, inherit.aes = FALSE) +
  labs(title = 'Cologne') +
  scale_fill_locuszoom(name='Foreigner share group') +
  annotation_scale(location = "bl", width_hint = 0.3, text_cex = 0.5) +  # Add a scale bar
  annotation_north_arrow(
    location = "tr", which_north = "true",
    style = north_arrow_fancy_orienteering(text_size = 6),
    height = unit(0.8, "cm"),  # Adjust arrow height
    width = unit(0.8, "cm")    # Adjust arrow width
  ) +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5)) +
  guides(fill = guide_legend(nrow = 1))

G3 <- ggarrange(g9, g10, g11, g12, ncol = 2, nrow = 2, common.legend = T)
ggsave(filename = paste0("figures/manuscript/pop_grps_f_maps_", policy, ".png"),
       plot=G3, width = 6, height = 6, unit = "in", dpi = 300, bg = 'white')

# Population groups/Net rent ----
g13 <- ggmap(berlin_basemap) +
  geom_sf(data = gdf2[!is.na(gdf2$r_grp), ], aes(fill=r_grp),
          color = 'white', size=0.05, alpha=0.7, show.legend = T, inherit.aes = FALSE) +
  labs(title = 'Berlin') +
  scale_fill_locuszoom(name='Net rent group') +
  annotation_scale(location = "bl", width_hint = 0.3, text_cex = 0.5) +  # Add a scale bar
  annotation_north_arrow(
    location = "tr", which_north = "true",
    style = north_arrow_fancy_orienteering(text_size = 6),
    height = unit(0.8, "cm"),  # Adjust arrow height
    width = unit(0.8, "cm")    # Adjust arrow width
  ) +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5)) +
  guides(fill = guide_legend(nrow = 1))

g14 <- ggmap(hamburg_basemap) +
  geom_sf(data = gdf2[!is.na(gdf2$r_grp), ], aes(fill=r_grp),
          color = 'white', size=0.05, alpha=0.7, show.legend = T, inherit.aes = FALSE) +
  labs(title = 'Hamburg') +
  scale_fill_locuszoom(name='Net rent group') +
  annotation_scale(location = "bl", width_hint = 0.3, text_cex = 0.5) +  # Add a scale bar
  annotation_north_arrow(
    location = "tr", which_north = "true",
    style = north_arrow_fancy_orienteering(text_size = 6),
    height = unit(0.8, "cm"),  # Adjust arrow height
    width = unit(0.8, "cm")    # Adjust arrow width
  ) +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5)) +
  guides(fill = guide_legend(nrow = 1))

g15 <- ggmap(munich_basemap) +
  geom_sf(data = gdf2[!is.na(gdf2$r_grp), ], aes(fill=r_grp),
          color = 'white', size=0.05, alpha=0.7, show.legend = T, inherit.aes = FALSE) +
  labs(title = 'Munich') +
  scale_fill_locuszoom(name='Net rent group') +
  annotation_scale(location = "bl", width_hint = 0.3, text_cex = 0.5) +  # Add a scale bar
  annotation_north_arrow(
    location = "tr", which_north = "true",
    style = north_arrow_fancy_orienteering(text_size = 6),
    height = unit(0.8, "cm"),  # Adjust arrow height
    width = unit(0.8, "cm")    # Adjust arrow width
  ) +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5)) +
  guides(fill = guide_legend(nrow = 1))

g16 <- ggmap(cologne_basemap) +
  geom_sf(data = gdf2[!is.na(gdf2$r_grp), ], aes(fill=r_grp),
          color = 'white', size=0.05, alpha=0.7, show.legend = T, inherit.aes = FALSE) +
  labs(title = 'Cologne') +
  scale_fill_locuszoom(name='Net rent group') +
  annotation_scale(location = "bl", width_hint = 0.3, text_cex = 0.5) +  # Add a scale bar
  annotation_north_arrow(
    location = "tr", which_north = "true",
    style = north_arrow_fancy_orienteering(text_size = 6),
    height = unit(0.8, "cm"),  # Adjust arrow height
    width = unit(0.8, "cm")    # Adjust arrow width
  ) +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5)) +
  guides(fill = guide_legend(nrow = 1))

G4 <- ggarrange(g13, g14, g15, g16, ncol = 2, nrow = 2, common.legend = T)
ggsave(filename = paste0("figures/manuscript/pop_grps_r_maps_", policy, ".png"),
       plot=G4, width = 6, height = 6, unit = "in", dpi = 300, bg = 'white')

# Population groups - National level ----
g19 <- ggplot() +
  geom_sf(data = gdf2[!is.na(gdf2$pt_grp), ], aes(fill=pt_grp),
          color = 'NA', alpha=1, show.legend = T) +
  scale_fill_locuszoom(name='') +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5)) +
  guides(fill = guide_legend(nrow = 1))

g17 <- ggplot() +
  geom_sf(data = gdf2[!is.na(gdf2$f_grp), ], aes(fill=f_grp),
          color = 'NA', alpha=1, show.legend = T) +
  scale_fill_locuszoom(name='') +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5)) +
  guides(fill = guide_legend(nrow = 1))

g18 <- ggplot() +
  geom_sf(data = gdf2[!is.na(gdf2$r_grp), ], aes(fill=r_grp),
          color = 'NA', alpha=1, show.legend = T) +
  scale_fill_locuszoom(name='') +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5)) +
  guides(fill = guide_legend(nrow = 1))

G5 <- ggarrange(g19, g17, g18, ncol = 3, nrow = 1, labels = c('a', 'b', 'c'),
                common.legend = T, legend="bottom")
ggsave(filename = paste0("figures/manuscript/grps_maps_national_", policy, ".png"),
       plot=G5, width = 15, height = 6, unit = "in", dpi = 300, bg = 'white')

# Population bivariate groups (kind) ----
policy <- 'dt'
kind <- 'nurban'
gdf2 <- st_transform(st_read(paste0("results/tdid/h3_groups_", policy, "_", kind, ".shp")), 4326)
gdf2 <- gdf2 %>%
  select(h3_id, fr_grp_t3) %>%
  filter(fr_grp_t3 != 'q0')
gdf2$fr_grp <- sub("q(\\d)q(\\d)", "\\1-\\2", gdf2$fr_grp_t3)

if (kind == 'urban'){
  ylb <- 'Visited by urban residents'
}else{
  ylb <- "Visited by non-urban residents"
}

g20 <- ggmap(berlin_basemap) +
  geom_sf(data = gdf2, mapping = aes(fill = fr_grp), color = "white", size = 0.1,
          show.legend = FALSE, inherit.aes = FALSE) +
  labs(title = 'Berlin', x='', y=ylb) +
  bi_scale_fill(pal = "DkViolet", dim = 3) +
  annotation_scale(location = "bl", width_hint = 0.3, text_cex = 0.5) +  # Add a scale bar
  annotation_north_arrow(
    location = "tr", which_north = "true",
    style = north_arrow_fancy_orienteering(text_size = 6),
    height = unit(0.8, "cm"),  # Adjust arrow height
    width = unit(0.8, "cm")    # Adjust arrow width
  ) +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5),
        axis.title.y = element_text(size = 12, margin = margin(r = 10), angle=90)) +
  guides(fill = guide_legend(nrow = 1))

g21 <- ggmap(hamburg_basemap) +
  geom_sf(data = gdf2, mapping = aes(fill = fr_grp), color = "white", size = 0.1,
          show.legend = FALSE, inherit.aes = FALSE) +
  labs(title = 'Hamburg', x='', y='') +
  bi_scale_fill(pal = "DkViolet", dim = 3) +
  annotation_scale(location = "bl", width_hint = 0.3, text_cex = 0.5) +  # Add a scale bar
  annotation_north_arrow(
    location = "tr", which_north = "true",
    style = north_arrow_fancy_orienteering(text_size = 6),
    height = unit(0.8, "cm"),  # Adjust arrow height
    width = unit(0.8, "cm")    # Adjust arrow width
  ) +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5)) +
  guides(fill = guide_legend(nrow = 1))

g22 <- ggmap(munich_basemap) +
  geom_sf(data = gdf2, mapping = aes(fill = fr_grp), color = "white", size = 0.1,
          show.legend = FALSE, inherit.aes = FALSE) +
  labs(title = 'Munich', x='', y='') +
  bi_scale_fill(pal = "DkViolet", dim = 3) +
  annotation_scale(location = "bl", width_hint = 0.3, text_cex = 0.5) +  # Add a scale bar
  annotation_north_arrow(
    location = "tr", which_north = "true",
    style = north_arrow_fancy_orienteering(text_size = 6),
    height = unit(0.8, "cm"),  # Adjust arrow height
    width = unit(0.8, "cm")    # Adjust arrow width
  ) +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5)) +
  guides(fill = guide_legend(nrow = 1))

g23 <- ggmap(cologne_basemap) +
  geom_sf(data = gdf2, mapping = aes(fill = fr_grp), color = "white", size = 0.1,
          show.legend = FALSE, inherit.aes = FALSE) +
  labs(title = 'Cologne', x='', y='') +
  bi_scale_fill(pal = "DkViolet", dim = 3) +
  annotation_scale(location = "bl", width_hint = 0.3, text_cex = 0.5) +  # Add a scale bar
  annotation_north_arrow(
    location = "tr", which_north = "true",
    style = north_arrow_fancy_orienteering(text_size = 6),
    height = unit(0.8, "cm"),  # Adjust arrow height
    width = unit(0.8, "cm")    # Adjust arrow width
  ) +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5)) +
  guides(fill = guide_legend(nrow = 1))

legend <- bi_legend(pal = "DkViolet",
                    dim = 3,
                    xlab = "Higher % Foreigner",
                    ylab = "Higher income",
                    size = 10) +
  theme(aspect.ratio = 1)  # Ensure the legend is square

# # combine map with legend
# g23 <- ggdraw() +
#   draw_plot(g23, 0, 0, 1, 1) +
#   draw_plot(legend, 0.7, 0.1, 0.2, 0.2)

G6 <- ggarrange(g20, g21, g22, g23, ncol = 4, nrow = 1)
G60 <- ggarrange(G6, legend, widths = c(1, 0.13), ncol = 2, nrow = 1)
ggsave(filename = paste0("figures/manuscript/bivariate_grps_maps_", policy, "_", kind, ".png"),
       plot=G60, width = 15, height = 3, unit = "in", dpi = 300, bg = 'white')
# if (kind == 'urban'){
#   ggsave(filename = paste0("figures/manuscript/bivariate_grps_maps_", policy, "_", kind, ".png"),
#        plot=G60, width = 15, height = 3, unit = "in", dpi = 300, bg = 'white')
# }else {
#   # The below for Non-urban results
#   ggsave(filename = paste0("figures/manuscript/bivariate_grps_maps_", policy, "_", kind, ".png"),
#        plot=G6, width = 13.4, height = 3, unit = "in", dpi = 300, bg = 'white')
# }

# Population bivariate groups ----
policy <- 'dt'
gdf2 <- st_transform(st_read(paste0("results/tdid/h3_groups_dt_fr.shp")), 4326)
gdf2 <- gdf2 %>%
  select(h3_id, fr_grp_t3) %>%
  filter(fr_grp_t3 != 'q0')
gdf2$fr_grp <- sub("q(\\d)q(\\d)", "\\1-\\2", gdf2$fr_grp_t3)

g24 <- ggmap(berlin_basemap) +
  geom_sf(data = gdf2, mapping = aes(fill = fr_grp), color = "white", size = 0.1,
          show.legend = FALSE, inherit.aes = FALSE) +
  labs(title = 'Berlin', x='', y='') +
  bi_scale_fill(pal = "DkViolet", dim = 3) +
  annotation_scale(location = "bl", width_hint = 0.3, text_cex = 0.5) +  # Add a scale bar
  annotation_north_arrow(
    location = "tr", which_north = "true",
    style = north_arrow_fancy_orienteering(text_size = 6),
    height = unit(0.8, "cm"),  # Adjust arrow height
    width = unit(0.8, "cm")    # Adjust arrow width
  ) +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5),
        axis.title.y = element_text(size = 12, margin = margin(r = 10), angle=90)) +
  guides(fill = guide_legend(nrow = 1))

g25 <- ggmap(hamburg_basemap) +
  geom_sf(data = gdf2, mapping = aes(fill = fr_grp), color = "white", size = 0.1,
          show.legend = FALSE, inherit.aes = FALSE) +
  labs(title = 'Hamburg', x='', y='') +
  bi_scale_fill(pal = "DkViolet", dim = 3) +
  annotation_scale(location = "bl", width_hint = 0.3, text_cex = 0.5) +  # Add a scale bar
  annotation_north_arrow(
    location = "tr", which_north = "true",
    style = north_arrow_fancy_orienteering(text_size = 6),
    height = unit(0.8, "cm"),  # Adjust arrow height
    width = unit(0.8, "cm")    # Adjust arrow width
  ) +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5)) +
  guides(fill = guide_legend(nrow = 1))

g26 <- ggmap(munich_basemap) +
  geom_sf(data = gdf2, mapping = aes(fill = fr_grp), color = "white", size = 0.1,
          show.legend = FALSE, inherit.aes = FALSE) +
  labs(title = 'Munich', x='', y='') +
  bi_scale_fill(pal = "DkViolet", dim = 3) +
  annotation_scale(location = "bl", width_hint = 0.3, text_cex = 0.5) +  # Add a scale bar
  annotation_north_arrow(
    location = "tr", which_north = "true",
    style = north_arrow_fancy_orienteering(text_size = 6),
    height = unit(0.8, "cm"),  # Adjust arrow height
    width = unit(0.8, "cm")    # Adjust arrow width
  ) +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5)) +
  guides(fill = guide_legend(nrow = 1))

g27 <- ggmap(cologne_basemap) +
  geom_sf(data = gdf2, mapping = aes(fill = fr_grp), color = "white", size = 0.1,
          show.legend = FALSE, inherit.aes = FALSE) +
  labs(title = 'Cologne', x='', y='') +
  bi_scale_fill(pal = "DkViolet", dim = 3) +
  annotation_scale(location = "bl", width_hint = 0.3, text_cex = 0.5) +  # Add a scale bar
  annotation_north_arrow(
    location = "tr", which_north = "true",
    style = north_arrow_fancy_orienteering(text_size = 6),
    height = unit(0.8, "cm"),  # Adjust arrow height
    width = unit(0.8, "cm")    # Adjust arrow width
  ) +
  theme_void() +
  theme(plot.margin = margin(0.1,0.1,0.1,0, "cm"),
        legend.position = 'top',
        plot.title = element_text(hjust = 0.5)) +
  guides(fill = guide_legend(nrow = 1))

legend <- bi_legend(pal = "DkViolet",
                    dim = 3,
                    xlab = "Higher % Foreigner",
                    ylab = "Higher income",
                    size = 10) +
  theme(aspect.ratio = 1)  # Ensure the legend is square

G7 <- ggarrange(g24, g25, g26, g27, ncol = 4, nrow = 1)
G70 <- ggarrange(G7, legend, widths = c(1, 0.13), ncol = 2, nrow = 1)
ggsave(filename = paste0("figures/manuscript/bivariate_grps_maps_", policy, ".png"),
       plot=G70, width = 15, height = 3, unit = "in", dpi = 300, bg = 'white')

