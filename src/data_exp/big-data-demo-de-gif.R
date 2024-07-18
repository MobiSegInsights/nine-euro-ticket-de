# Title     : Raw stops in Berlin, Germany
# Objective : GIF of central Berlin - 24 hours
# Created by: Yuan Liao
# Created on: 2024-07-15

library(arrow)
library(tidyr)
library(tictoc)
library(dplyr)
library(ggplot2)
library(animation)

# Berlin
bbox <- c(13.0883448198,52.3382710278,13.761160858,52.6755087668)
# Assign the coordinates to variables for clarity
min_lng <- bbox[1]
min_lat <- bbox[2]
max_lng <- bbox[3]
max_lat <- bbox[4]
df.stops <- open_dataset("dbs/stops_p/")
# df.stops <- as.data.frame(read_parquet('dbs/visits_day_did_states/Berlin.parquet'))
# Filter the dataframe
df.stops <- df.stops %>%
  select(longitude, latitude, h_s) %>%
  filter(longitude >= min_lng & longitude <= max_lng & latitude >= min_lat & latitude <= max_lat) %>%
  collect()

x0 <- min_lng # minimum longitude to plot
y0 <- min_lat   # minimum latitude to plot
span_lng <- max_lng - min_lng  # size of the long window to plot
span_lat <- max_lat - min_lat  # size of the lat window to plot

pixels_lat <- 2000*span_lat
pixels_lng <- 2000*span_lng

df.stops.agg <- df.stops %>%
  mutate(
    unit_scaled_x = (longitude - x0) / span_lng,
    unit_scaled_y = (latitude - y0) / span_lat,
    x = as.integer(round(pixels_lng * unit_scaled_x)),
    y = as.integer(round(pixels_lat * unit_scaled_y))
  ) %>%
  group_by(h_s) %>%
  count(x, y, name = "stop") %>%
  collect()

render_image <- function(mat, cols = c("white", "#800020"), main_title = NULL) {
  op <- par(mar = c(0, 0, 0, 0))
  shades <- colorRampPalette(cols)
  image(
    z = log10(t(mat + 1)),
    axes = FALSE,
    asp = 1,
    col = shades(256),
    useRaster = TRUE
  )
  # Add title if provided
  if (!is.null(main_title)) {
    title(main = main_title, col.main = "white", cex.main = 1.5, line = -2)
  }
  par(op)
}

saveGIF({
  for (hour in 0:23){
    grid <- expand_grid(x = 1:pixels_lng, y = 1:pixels_lat) %>%
    left_join(df.stops.agg[df.stops.agg$h_s == hour,], by = c("x", "y")) %>%
    mutate(stop = replace_na(stop,  0))

    stops_grid <- matrix(
      data = grid$stop,
      nrow = pixels_lat,
      ncol = pixels_lng
    )
    render_image(stops_grid, cols = c("#002222", "white", "#800020"), main_title=paste('Hour:',hour))}
}, interval = .2, movie.name="activities_berlin_animation.gif")