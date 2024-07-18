# Title     : Raw stops in Berlin, Germany
# Objective : On the map of central Berlin
# Created by: Yuan Liao
# Created on: 2024-07-11

library(arrow)
library(tidyr)
library(tictoc)
library(dplyr)
library(ggplot2)

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
  select(longitude, latitude) %>%
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
  count(x, y, name = "stop") %>%
  collect()

grid <- expand_grid(x = 1:pixels_lng, y = 1:pixels_lat) %>%
  left_join(df.stops.agg, by = c("x", "y")) %>%
  mutate(stop = replace_na(stop,  0))

stops_grid <- matrix(
  data = grid$stop,
  nrow = pixels_lat,
  ncol = pixels_lng
)

render_image <- function(mat, cols = c("white", "#800020")) {
  op <- par(mar = c(0, 0, 0, 0))
  shades <- colorRampPalette(cols)
  image(
    z = log10(t(mat + 1)),
    axes = FALSE,
    asp = 1,
    col = shades(256),
    useRaster = TRUE
  )
  par(op)
}

# Specify the file name
file_name <- "figures/berlin_mobile_data.png"

# Open a graphics device
png(file_name, width = 2000, height = 2000)

# Render the image
render_image(stops_grid, cols = c("#002222", "white", "#800020"))

# Close the graphics device
dev.off()

# Confirm the image was saved
print(paste("Image saved to", file_name))

