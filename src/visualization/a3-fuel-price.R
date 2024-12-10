library(dplyr)
library(pastecs)
library(ggplot2)
library(DBI)
library(RPostgres)
library(yaml)
library(ggsci)
library(ggthemes)
library(ggpubr)
library(data.table)
library(scales) # to access break formatting functions

# Load descriptive stats from the database
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

df <- dbGetQuery(con, 'SELECT * FROM fuel_price')
df <- df %>%
  mutate(e=(e5 + e10) / 2)

g <- ggplot(data=df, aes(x=Time, y=e, group=Year, color=Year)) +
  geom_line() +
  scale_color_npg(name='Year') +
  theme_hc() +
  labs(x='Time', y='Fuel price (\U20AC/L)') +
  scale_x_discrete(breaks = c("02-01", "03-01", "04-01",
                              "05-02", "06-01", "07-01",
                              "08-01", "09-01"),
  labels = c("Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep")) +  # Adjust x-axis labels if needed
  theme(panel.grid = element_blank(), strip.background = element_blank())

ggsave(filename = "figures/manuscript/fuel_price.png", plot=g,
       width = 8, height = 4, unit = "in", dpi = 300, bg = 'white')