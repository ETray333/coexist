## 20250418
library(RPostgres)
library(sf)
library(dplyr)

# Connect to DB
# Database parameters
db_host <- "localhost"
db_port <- 5432
db_name <- "postgres"
db_user <- "postgres"
db_password <- "fusion"

# Set up database connection
conn <- dbConnect(
  RPostgres::Postgres(),
  host = db_host,
  port = db_port,
  dbname = db_name,
  user = db_user,
  password = db_password
)

# Add new geartype_grouped column to house grouped name values
DBI::dbExecute(conn, "
  ALTER TABLE effort_observed ADD COLUMN geartype_grouped TEXT;
")

# Update with grouped values
DBI::dbExecute(conn, "
  UPDATE effort_observed
  SET geartype_grouped = CASE
    WHEN geartype IN ('drifting_longlines', 'pole_and_line', 'trollers') THEN 'mobile_lines'
    WHEN geartype IN ('fixed_gear', 'pots_and_traps', 'set_gillnets', 'set_longlines') THEN 'static'
    WHEN geartype IN ('trawlers', 'dredge_fishing', 'tuna_purse_seines', 'other_seines', 'other_purse_seines', 'purse_seines', 'seiners') THEN 'towed'
    WHEN geartype IN ('fishing', 'inconclusive') THEN 'inconclusive'
    ELSE geartype
  END;
")

# To make the rest of the script reusable, create seperate materialized views for each geartype. 
# This will allow us to make the expanded dataframes similar to the total fishing and we can just target different views.
query_mat_view_towed <- "
CREATE MATERIALIZED VIEW effort_observed_towed AS
SELECT 
  cell_ll_lat,
  cell_ll_lon,
  ROUND(dec_date::numeric, 3) AS dec_date,
  area_modelling_window,
  'towed' AS geartype,
  SUM(fishing_hours) AS fishing_hours
FROM effort_observed
WHERE geartype_grouped = 'towed'
GROUP BY cell_ll_lat, cell_ll_lon, ROUND(dec_date::numeric, 3), area_modelling_window;
"

DBI::dbExecute(conn, query_mat_view_towed)

# Create an index on the materialized view to speed up queries
query_towed_effort_index <- "
CREATE INDEX idx_effort_towed ON effort_observed_towed (cell_ll_lat, cell_ll_lon, dec_date, area_modelling_window);
"

dbExecute(conn, query_towed_effort_index)

query_mat_view_static <- "
CREATE MATERIALIZED VIEW effort_observed_static AS
SELECT 
  cell_ll_lat,
  cell_ll_lon,
  ROUND(dec_date::numeric, 3) AS dec_date,
  area_modelling_window,
  'static' AS geartype,
  SUM(fishing_hours) AS fishing_hours
FROM effort_observed
WHERE geartype_grouped = 'static'
GROUP BY cell_ll_lat, cell_ll_lon, ROUND(dec_date::numeric, 3), area_modelling_window;
"

DBI::dbExecute(conn, query_mat_view_static)

query_static_effort_index <- "
CREATE INDEX idx_effort_static ON effort_observed_static (cell_ll_lat, cell_ll_lon, dec_date, area_modelling_window);
"

dbExecute(conn, query_static_effort_index)

materialized_views <- c("effort_observed_towed","effort_observed_static")

mw_areas <- c(
  "area_a",
  "area_b_east",
  "area_b_west",
  "area_c",
  "area_d"
)

for(mat_view_i in materialized_views){
  
  print(mat_view_i)
  
  for (area in mw_areas) {
    
    print(area)
    # Step 1: Create expanded grid (effort_expanded_total_<area>)
    sql_expanded <- paste0("
    CREATE MATERIALIZED VIEW ", mat_view_i, "_", area, "_expanded", " AS
    WITH
      lat_range AS (
        SELECT MIN(ROUND(cell_ll_lat::numeric, 2)) AS min_lat,
               MAX(ROUND(cell_ll_lat::numeric, 2)) AS max_lat
        FROM ", mat_view_i, 
                           " WHERE area_modelling_window = '", area, "'
      ),
      lon_range AS (
        SELECT MIN(ROUND(cell_ll_lon::numeric, 2)) AS min_lon,
               MAX(ROUND(cell_ll_lon::numeric, 2)) AS max_lon
        FROM ", mat_view_i, 
                           " WHERE area_modelling_window = '", area, "'
      ),
      lat_series AS (
        SELECT generate_series(min_lat, max_lat, 0.01) AS cell_ll_lat
        FROM lat_range
      ),
      lon_series AS (
        SELECT generate_series(min_lon, max_lon, 0.01) AS cell_ll_lon
        FROM lon_range
      ),
      date_series AS (
        SELECT DISTINCT dec_date
        FROM ", mat_view_i, 
                           " WHERE area_modelling_window = '", area, "'
      ),
      grid AS (
        SELECT cell_ll_lat, cell_ll_lon, dec_date
        FROM lat_series, lon_series, date_series
      )
    SELECT 
      cell_ll_lat,
      cell_ll_lon,
      dec_date,
      '", area, "' AS area_modelling_window
    FROM grid;
  ")
    
    message("Creating expanded view for ", mat_view_i, " ", area)
    dbExecute(conn, sql_expanded)
  }
  
}

### use gears instead to make naming easier

geartype_id <- c("towed", "static")

for(geartype_i in geartype_id){
  
  print(geartype_i)
  
  
  for (area in mw_areas) {
    # Step 2: Join with observed totals to create final combined view
    sql_combined <- paste0("
    CREATE MATERIALIZED VIEW effort_combined_", geartype_i, "_", area, " AS
    SELECT 
      g.cell_ll_lat,
      g.cell_ll_lon,
      g.dec_date,
      g.area_modelling_window,
      '", geartype_i, "' AS geartype,
      COALESCE(o.fishing_hours, 0) AS fishing_hours
    FROM effort_observed_", geartype_i, "_", area, "_expanded g
    LEFT JOIN effort_observed_", geartype_i, " o
      ON g.cell_ll_lat = o.cell_ll_lat
      AND g.cell_ll_lon = o.cell_ll_lon
      AND g.dec_date = o.dec_date
      AND g.area_modelling_window = o.area_modelling_window;
  ")
    
    message("Creating combined view for ", geartype_i,  area)
    dbExecute(conn, sql_combined)
    
  }
  
}

for(geartype_i in geartype_id){
  
  print(geartype_i)
  
  for (area in mw_areas) {
    # Step 3: Add index on the combined view
    sql_index <- paste0("
    CREATE INDEX idx_effort_combined_", geartype_i, "_", area, " 
    ON effort_combined_", geartype_i, "_", area, " (cell_ll_lat, cell_ll_lon, dec_date, area_modelling_window, geartype);
  ")
    
    message("Creating index for combined ", geartype_i, " ", area)
    dbExecute(conn, sql_index)
    
  }
  
}

# import all combined dataframes
for (area in mw_areas) {
  
  # Build view name and query
  view_name <- paste0("effort_combined_total_", area)
  sql <- paste0("SELECT * FROM ", view_name)
  
  # Read the table
  effort_data <- dbGetQuery(conn, sql)
  
  # Assign to a variable like area_a_effort
  var_name <- paste0(area, "_effort_combined")
  assign(var_name, effort_data, envir = .GlobalEnv)
  
  message("Imported: ", var_name)
}


# import all expanded dataframes
# for (area in mw_areas) {
# 
#   # Build view name and query
#   view_name <- paste0("effort_expanded_", area)
#   sql <- paste0("SELECT * FROM ", view_name)
# 
#   # Read the table
#   effort_data <- dbGetQuery(conn, sql)
# 
#   # Assign to a variable like area_a_effort
#   var_name <- paste0(area, "_effort")
#   assign(var_name, effort_data, envir = .GlobalEnv)
# 
#   message("Imported: ", var_name)
# }

# Test for rows of effort in combined with source data
effort_over_0_source <- matrix_data_27.4.b_east %>%
  st_drop_geometry() %>%
  group_by(cell_ll_lat, cell_ll_lon, dec_date, area_modelling_window) %>%
  summarize(sum_fishing_hours = sum(fishing_hours, na.rm = T), .groups ="keep") %>%
  filter(sum_fishing_hours > 0)

effort_over_0_postgres <- area_b_east_effort_combined %>%
  st_drop_geometry() %>%
  group_by(cell_ll_lat, cell_ll_lon, dec_date, area_modelling_window) %>%
  summarize(sum_fishing_hours = sum(fishing_hours, na.rm = T), .groups ="keep") %>%
  filter(sum_fishing_hours > 0)


