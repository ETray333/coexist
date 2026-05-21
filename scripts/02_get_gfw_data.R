

# May 20th 2026
# etray
# Go to globalfishingwatch.org/our-apis/tokens to get a token

#install.packages("gfwr", repos = c("https://globalfishingwatch.r-universe.dev", "https://cran.r-project.org"))

#install.packages("usethis")

usethis::edit_r_environ()
library(gfwr)
gfw_auth()


# List all EEZs
eez_regions <- gfw_regions(region_source = "EEZ")
eez_regions  # Browse this

# Or look up a specific country (ISO3 code)
gfw_region_id(region = "PNG", region_source = "EEZ")  # Papua New Guinea example

library(gfwr)
library(dplyr)
library(sf)
library(purrr)

# Download fishing hours grouped by GEARTYPE
# Note: date range cannot exceed 366 days per call
# Load your shapefile
# my_area <- st_read("your_area.shp")
my_area <- st_read("C:/Users/Elizabeth.Tray/Documents/GitHub/coexist/data/processed/ices_areas_shapefiles_both_unzipped_and_zipped_processed_on_2026-05-20/27.7.d/27.7.d.shp")

# Create the output folder if it doesn't exist yet
dir.create("C:/Users/Elizabeth.Tray/Documents/GitHub/coexist/data/processed/added_windows_gfw_data", 
           showWarnings = FALSE)

# Download fishing hours grouped by GEARTYPE
fishing_by_gear_custom <- gfw_ais_fishing_hours(
  spatial_resolution  = "HIGH",
  temporal_resolution = "DAILY",
  group_by            = "GEARTYPE",
  start_date          = "2021-01-01",
  end_date            = "2021-12-31",
  region              = my_area,
  region_source       = "USER_SHAPEFILE"
)

# Save the result to the new folder
write.csv(fishing_by_gear_custom, 
          "C:/Users/Elizabeth.Tray/Documents/GitHub/coexist/data/processed/added_windows_gfw_data/gfw_27.7.d_2021_by_geartype.csv",
          row.names = FALSE)


