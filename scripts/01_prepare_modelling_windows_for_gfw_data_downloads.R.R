
# 20/5/2026 - prepare modelling windows for GFW data download
# etray

#1. Download the open source ICES areas shapefile
#2. Separate these to individual polygons - GFW has size limits, so best to do one at a time
#3. Export these into raw data folder. This folder contains the files needed to download the data from GFW for individual ICES areas

library(sf)
library(dplyr)

# data for ICES areas can be downloaded at this link:
# https://gis.ices.dk/shapefiles/ICES_areas.zip

# read data
external_data <- "C:/Users/Elizabeth.Tray/Documents/GitHub/coexist/data/raw/ices_areas/ICES_Areas_20160601_cut_dense_3857.shp"

ices_data <- st_read(external_data)
ices_data <- st_make_valid(ices_data)
ices_data <- st_transform(ices_data, 4326)

# base directory
base_dir <- "C:/Users/Elizabeth.Tray/Documents/GitHub/coexist/data/processed"

# date stamp
today <- format(Sys.Date(), "%Y-%m-%d")

# parent folder (THIS is what you were missing in use)
output_dir <- file.path(
  base_dir,
  paste0("ices_areas_processed_to_individual_shapefiles_on_", today)
)

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# loop safely
unique_ids <- unique(ices_data$Area_Full)

for (id in unique_ids) {
  
  # subset
  poly <- ices_data %>%
    filter(Area_Full == id)
  
  # shapefiles are fussy with naming
  # Replace any character that is NOT a letter, number, underscore, or dot with an underscore”
  safe_name <- gsub("[^A-Za-z0-9_\\.]", "_", id)
  
  # IMPORTANT: use output_dir (NOT base_dir)
  folder_path <- file.path(output_dir, safe_name)
  
  dir.create(folder_path, recursive = TRUE, showWarnings = FALSE)
  
  # write shapefile (robust GDAL method)
  st_write(
    poly,
    dsn = folder_path,
    layer = safe_name,
    driver = "ESRI Shapefile",
    delete_layer = TRUE,
    quiet = TRUE
  )
}


