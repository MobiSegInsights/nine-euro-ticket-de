library(magick)

read.img <- function(path, lb){
  image <- image_read(path) %>%
    image_annotate(lb, gravity = "northwest", color = "black", size = 70, weight = 700)
  return(image)
}

# ----- PT group -------
image1 <- read.img(path="figures/manuscript/pt_grps.png", lb='b')
image2 <- read.img(path="figures/manuscript/pt_grps_maps_dt.png", lb='a')


## Combine images 2-4
# Get width of image 2
image1_height <- image_info(image1)$height

# Create blank space between them and stack three
blank_space_h <- image_blank(2, image1_height, color = "white")
combined_image <- image_append(c(image2, blank_space_h, image1), stack = F)
image_write(combined_image, "figures/manuscript/pt_grps_h.png")

# ----- Activity-type cluster -------
image3 <- read.img(path="figures/manuscript/activity_type_cluster_grps.png", lb='b')
image4 <- read.img(path="figures/manuscript/activity_type_cluster_grps_maps_dt.png", lb='a')


## Combine images 2-4
# Get width of image 2
image_height <- image_info(image3)$height

# Create blank space between them and stack three
blank_space_h <- image_blank(2, image_height, color = "white")
combined_image <- image_append(c(image4, blank_space_h, image3), stack = F)
image_write(combined_image, "figures/manuscript/activity_type_cluster_grps_h.png")

# ----- Population groups -------
image5 <- read.img(path="figures/manuscript/pop_grps_f_maps_dt.png", lb='a')
image6 <- read.img(path="figures/manuscript/pop_grps_r_maps_dt.png", lb='b')
image7 <- read.img(path="figures/manuscript/pop_grps.png", lb='c')


image5_height <- image_info(image5)$height

# Create blank space between them and stack three
blank_space_h <- image_blank(2, image5_height, color = "white")
combined_image1 <- image_append(c(image5, blank_space_h, image6), stack = F)

# Get height of image 1
image1_width <- image_info(combined_image1)$width

# Create a blank space image
blank_space_w <- image_blank(image1_width, 2, color = "white")

# Combine the images side by side
combined_image <- image_append(c(combined_image1, blank_space_w, image7), stack = T)

image_write(combined_image, "figures/manuscript/pop_grps_h.png")

# ----- Population bivariate groups (kind) -------
kind <- 'nurban'
image8 <- read.img(path=paste0("figures/manuscript/bivariate_grps_maps_dt", "_", kind, ".png"), lb='a')
image10 <- read.img(path=paste0("figures/manuscript/", kind, "_pop_grps_thr3.png"), lb='b')
image8_width <- image_info(image8)$width

# Create a blank space image
blank_space_w <- image_blank(image8_width, 2, color = "white")

# Combine the images side by side
combined_image <- image_append(c(image8, blank_space_w, image10), stack = T)

image_write(combined_image, paste0("figures/manuscript/pop_bi_grps_h", kind, ".png"))

# Population bivariate groups (kind- variable combined)
image13 <- read.img(path=paste0("figures/manuscript/bivariate_grps_maps_dt", "_", 'nurban', ".png"), lb='a')
image14 <- read.img(path=paste0("figures/manuscript/bivariate_grps_maps_dt", "_", 'urban', ".png"), lb='b')
image13_width <- image_info(image13)$width

# Create a blank space image
blank_space_w <- image_blank(image13_width, 2, color = "white")

# Combine the images side by side
combined_image <- image_append(c(image13, blank_space_w, image14), stack = T)

image_write(combined_image, "figures/manuscript/pop_bi_grps_h_maps.png")

# ----- Population bivariate groups ----
image11 <- read.img(path=paste0("figures/manuscript/bivariate_grps_maps_dt.png"), lb='a')
image12 <- read.img(path=paste0("figures/manuscript/pop_grps_thr3.png"), lb='b')
image11_width <- image_info(image11)$width

# Create a blank space image
blank_space_w <- image_blank(image11_width, 2, color = "white")

# Combine the images side by side
combined_image <- image_append(c(image11, blank_space_w, image12), stack = T)

image_write(combined_image, paste0("figures/manuscript/pop_bi_grps_h.png"))