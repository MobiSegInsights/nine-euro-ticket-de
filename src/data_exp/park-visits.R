# Title     : Park visits in Germany
# Objective : Country-level visualization
# Created by: Yuan Liao
# Created on: 2024-07-15

library(arrow)
library(tidyr)
library(tictoc)
library(RPostgres)
library(dplyr)
library(yaml)
library(sf)
library(ggplot2)
library(ggthemes)

keys_manager <- read_yaml('./dbs/keys.yaml')
user <- keys_manager$database$user
password <- keys_manager$database$password
port <- keys_manager$database$port
db_name <- keys_manager$database$name
con <- DBI::dbConnect(RPostgres::Postgres(),
                      host = "localhost",
                      dbname = db_name,
                      user = user,
                      password = password,
                      port = port)
df.poi <- st_read(con, query="SELECT osm_id, geom FROM poi")
# Extract latitude and longitude
df.poi <- df.poi %>%
  mutate(latitude = st_coordinates(.)[,2],
         longitude = st_coordinates(.)[,1])
# Berlin
bbox <- c(5.8663149923,47.270111618,15.04193075,55.0991611588)
# Assign the coordinates to variables for clarity
min_lng <- bbox[1]
min_lat <- bbox[2]
max_lng <- bbox[3]
max_lat <- bbox[4]

x0 <- min_lng # minimum longitude to plot
y0 <- min_lat   # minimum latitude to plot
span_lng <- max_lng - min_lng  # size of the long window to plot
span_lat <- max_lat - min_lat  # size of the lat window to plot

# df.stops <- open_dataset("dbs/visits_day_did/")
df.stops <- as.data.frame(read_parquet("dbs/visits_day_did/Recreation & Sports Centres.parquet"))

# Merge the DataFrames
df.stops <- df.stops %>%
  select(osm_id, year, num_visits_wt) %>%
  left_join(select(df.poi, osm_id, latitude, longitude), by = "osm_id") %>%
  select(longitude, latitude, year, num_visits_wt) %>%
  filter(longitude >= min_lng & longitude <= max_lng & latitude >= min_lat & latitude <= max_lat) %>%
  collect()

pixels_lat <- 500*span_lat
pixels_lng <- 500*span_lng

df.stops.agg <- df.stops %>%
  mutate(
    unit_scaled_x = (longitude - x0) / span_lng,
    unit_scaled_y = (latitude - y0) / span_lat,
    x = as.integer(round(pixels_lng * unit_scaled_x)),
    y = as.integer(round(pixels_lat * unit_scaled_y))
  ) %>%
  group_by(x, y, year) %>%
  summarise(stop=sum(num_visits_wt)) %>%
  collect()

# # Normalize the stop column by year
# df.stops.agg <- df.stops.agg %>%
#   group_by(year) %>%
#   mutate(
#     stop_min = min(stop),
#     stop_max = max(stop),
#     stop_normalized = (stop - stop_min) / (stop_max - stop_min)
#   ) %>%
#   ungroup() %>%
#   select(-stop_min, -stop_max)  # Remove intermediate columns

render_image <- function(mat, cols = c("white", "#800020"), main_title=NULL) {
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
    title(main = main_title, col.main = "white", cex.main = 5, line = -4)
  }
  par(op)
}

for (year in c(2019, 2022, 2023)){
  grid <- expand_grid(x = 1:pixels_lng, y = 1:pixels_lat) %>%
  left_join(df.stops.agg[df.stops.agg$year == year,], by = c("x", "y")) %>%
  mutate(stop = replace_na(stop,  0))

  stops_grid <- matrix(
    data = grid$stop,
    nrow = pixels_lat,
    ncol = pixels_lng
  )
  # Specify the file name
  file_name <- paste0("figures/berlin_recreation_", year, ".png")

  # Open a graphics device
  png(file_name, width = 2000, height = 2000)

  # Render the image
  render_image(stops_grid, cols = c("#002222", "white", "#800020"), main_title = year)

  # Close the graphics device
  dev.off()

  # Confirm the image was saved
  print(paste("Image saved to", file_name))
}

# Visit increase ----
g <- ggplot(data=df.stops.agg,
            aes(x=stop, fill=factor(year))) +
  theme_hc() +
  geom_density(position = "identity", alpha = 0.6, bins = 30) +
  scale_x_continuous(trans = "log10") +
  scale_fill_manual(values = c("2022" = "blue", "2023" = "red")) +
  labs(title = "Distribution of Stop by Year",
       x = "Stop",
       y = "Count",
       fill = "Year")

g