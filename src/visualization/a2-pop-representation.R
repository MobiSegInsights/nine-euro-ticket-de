# Load necessary libraries
library(sf)
library(ggplot2)
library(scico)
library(dplyr)
library(ggthemes)
library(ggsci)
library(ggpubr)
options(scipen=10000)

pop <- st_read("results/stats/pop_representation.shp")

# Scatter plot ----
g1 <- ggplot(data = pop) +
  theme_hc() +
  geom_point(aes(x=pop, y=d_count), size = 0.01, alpha=0.3, color='black') +
  scale_y_log10() +
  scale_x_log10() +
  geom_abline(intercept = 0, slope = 1, size=0.3, color='gray45') +
  labs(y = "Population size", x = "Device count")

# Spatial plot ----
g2 <- ggplot(data = pop) +
  theme_void() +
  geom_sf(color=NA, fill='gray75') +
  geom_sf(aes(fill=d_count/d_pop), color=NA) +
  scale_fill_scico(name = "Representation ratio", trans = 'log10',palette = "bamako",
                 breaks = c(0.01, 0.1, 1, 10, 100, 1000),
                 labels = c("0.01", "0.1", "1", "10", "100", "1000")) +
  theme(legend.position = "bottom", legend.key.width = unit(1, "cm"),
        panel.grid = element_blank())

# Calculate the CCDF
data.p <- pop %>%
  filter(d_count > 0) %>%
  count(pop) %>%
  arrange(pop) %>%
  mutate(cumulative_count_p = cumsum(n),
         cdf_p = cumulative_count_p / sum(n))

data.d <- pop %>%
  filter(d_count > 0) %>%
  count(d_count) %>%
  arrange(d_count) %>%
  mutate(cumulative_count_d = cumsum(n),
         cdf_d = cumulative_count_d / sum(n))

data.dc <- pop %>%
  filter(d_count > 0) %>%
  count(d_pop) %>%
  arrange(d_pop) %>%
  mutate(cumulative_count_dc = cumsum(n),
         cdf_dc = cumulative_count_dc / sum(n))


g3 <- ggplot() +
  theme_hc() +
  geom_line(data=data.p, aes(x=pop, y = cdf_p, color = "Census"), size=2, alpha=0.5) +
  geom_line(data=data.d, aes(x=d_count, y = cdf_d, color = "Devices"), size=1) +
  geom_line(data=data.dc, aes(x=d_pop, y = cdf_dc, color = "Devices-weighted"), size=1) +
  scale_color_npg(name = "Source") +
  scale_x_log10() +
  labs(y = 'Fraction of grids with X > x',
       x = 'No. of people/devices (X)') +
  guides(color = guide_legend(ncol = 1)) +
  theme(legend.position = c(.8, .2),
        legend.background = element_blank())

G <- ggarrange(g1, g2, g3, ncol = 3, nrow = 1, labels = c('a', 'b', 'c'))
ggsave(filename = "figures/manuscript/a2_pop_rep.png", plot=G,
       width = 15, height = 5, unit = "in", dpi = 300)