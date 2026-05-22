
# 20/5/2026 - prepare modelling windows for GFW data download
# etray

#1. Download the open source ICES areas shapefile
#2. Separate these to individual polygons 
#3. Export these into raw data folder. 

library(sf)
library(dplyr)

# data for ICES areas can be downloaded at this link:
# https://gis.ices.dk/shapefiles/ICES_areas.zip

# read data
external_data <- "C:/Users/Elizabeth.Tray/Documents/GitHub/coexist/data/raw/ices_areas/ICES_Areas_20160601_cut_dense_3857.shp"

ices_data <- st_read(external_data)
ices_data <- st_make_valid(ices_data)
ices_data <- st_transform(ices_data, 4326)

# do a new folder with them zipped - that is how they go into GFW
base_dir <- "C:/Users/Elizabeth.Tray/Documents/GitHub/coexist/data/processed"
today <- format(Sys.Date(), "%Y-%m-%d")
output_dir <- file.path(
  base_dir,
  paste0("ices_areas_shapefiles_both_unzipped_and_zipped_processed_on_", today)
)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

unique_ids <- unique(ices_data$Area_Full)
for (id in unique_ids) {
  
  # subset
  poly <- ices_data %>%
    filter(Area_Full == id)
  
  # shapefiles are fussy with naming
  # Replace any character that is NOT a letter, number, underscore, or dot with an underscore
  safe_name <- gsub("[^A-Za-z0-9_\\.]", "_", id)
  
  # folder for shapefile components
  folder_path <- file.path(output_dir, safe_name)
  dir.create(folder_path, recursive = TRUE, showWarnings = FALSE)
  
  # write shapefile
  st_write(
    poly,
    dsn = folder_path,
    layer = safe_name,
    driver = "ESRI Shapefile",
    delete_layer = TRUE,
    quiet = TRUE
  )
  
  zip_file <- file.path(output_dir, paste0(safe_name, ".zip"))
  
  zip(
    zipfile = zip_file,
    files = list.files(folder_path, full.names = TRUE)
  )
}

#TODO load these shapes into PostGreSQL








