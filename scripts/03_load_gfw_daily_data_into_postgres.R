# Create table in postgresql and load gfw csv into table

# Libraries
library(RPostgres)
library(tidyverse)
library(sf)
library(mapview)

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

# Table to create / make changes to
target_table <- "test_table2"

# Directory where all csv's are located
data_dir <- './elizabeth_tray/recent_years_for_EU_EEz/'

# List all files in above directory
effort_files <- tibble(
  file = list.files(paste0(data_dir), 
                    pattern = '.csv', recursive = T, full.names = T))


# Loop through all files and populate postgres
for(i in 1:length(effort_files$file)){
  
  # Here we are looping through 1:length(effort_files). 
  # So if we print i, we can see it is a sequence from 1 to the number of files.
  print(i)
  
  # We use this to select a specific file using the square brakcets
  # e.g. In the first loop, i = 1, so effort_files$file[1] will be the first file path
  # The next loop, i = 2, so effort_files$file[2] will be the second file path etc
  
  xl_file <- effort_files$file[i]
  
  
  # Here we have an if statement, to create the table if it's the first file path
  if(i == 1){
    print("This is the first file")
    print(xl_file)
    
    # Read in the data from the file path
    dat_xl_file <- read_csv(xl_file, show_col_types = FALSE)
    
    # Create table
    dbWriteTable(conn, target_table,
                 dat_xl_file,
                 overwrite = FALSE,
                 append = TRUE,
                 row.names = FALSE
    )
    
    
    # If it's not the first value, then we want to appent the data to the above created table
  } else {
    print("This is not the first file and will be appended")
    print(xl_file)
    
    # Read in the data from the path
    dat_xl_file <- read_csv(xl_file, show_col_types = FALSE)
    
    # Append data
    dbWriteTable(conn, target_table,
                 dat_xl_file,
                 overwrite = FALSE,
                 append = TRUE,
                 row.names = FALSE
    )
  }
  
}


