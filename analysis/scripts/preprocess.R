# R version 3.6.1
# Packages as of 2019-08/10

# setwd
setwd('~/bots/2019-08-fb-ad-library/analysis/')

# load packages
if(!require(dotenv)) {
  install.packages('dotenv', repos='http://cran.us.r-project.org')
  require(dotenv)
}
if (!require(httr)) {
  install.packages("httr", repos = "http://cran.us.r-project.org")
  require(httr)
}
if (!require(jsonlite)) {
  install.packages("jsonlite", repos = "http://cran.us.r-project.org")
  require(jsonlite)
}
if (!require(glue)) {
  install.packages("glue", repos = "http://cran.us.r-project.org")
  require(glue)
}
if (!require(tidyverse)) {
  install.packages("tidyverse", repos = "http://cran.us.r-project.org")
  require(tidyverse)
}
if (!require(magrittr)) {
  install.packages("magrittr", repos = "http://cran.us.r-project.org")
  require(magrittr)
}
if (!require(lubridate)) {
  install.packages("lubridate", repos = "http://cran.us.r-project.org")
  require(lubridate)
}
if (!require(purrr)) {
  install.packages("purrr", repos = "http://cran.us.r-project.org")
  require(purrr)
}
if (!require(stringr)) {
  install.packages("stringr", repos = "http://cran.us.r-project.org")
  require(stringr)
}
if (!require(tools)) {
  install.packages("tools", repos = "http://cran.us.r-project.org")
  require(tools)
}

load_dot_env('.env')

# load one file to get complete set of variables
distinct_variables <- c(
  "page_name",
  "page_id",
  "funding_entity",
  "ad_creation_time",
  "ad_delivery_start_time",
  "ad_delivery_stop_time",
  "ad_creative_body",
  "ad_snapshot_url",
  "demographic_distribution",
  "region_distribution",
  "impressions",
  "spend",
  "currency",
  "ad_creative_link_caption",
  "ad_creative_link_title",
  "ad_creative_link_description",
  "search_expression")

# prepare global variables
uuid_counter <- 0
ads <- tibble()
dem_dist <- tibble()
reg_dist <- tibble()

process_data <- function(data, scrape_date){
  # add unique id
  data %<>%
    mutate(uuid = glue::glue("{uuid_counter}-{row_number()}"))
  uuid_counter <<- uuid_counter + 1
  # add scrape date
  data %<>%
    mutate(scrape_date = scrape_date)
  # extract secondary data frames
  dem_dist <<- dem_dist %>% 
    bind_rows(
      data %>% 
        rowwise() %>% 
        # filter out those which have an empty data frame
        filter(length(demographic_distribution) > 0) %>% 
        ungroup() %>% 
        select(demographic_distribution, uuid) %>% 
        unnest() %>% 
        mutate(uuid = uuid)
    )
  reg_dist <<- reg_dist %>% 
    bind_rows(
      data %>% 
        rowwise() %>% 
        # filter out those which have an empty data frame
        filter(length(region_distribution) > 0) %>% 
        ungroup() %>% 
        select(region_distribution, uuid) %>% 
        unnest() %>% 
        mutate(uuid = uuid)
    )
  data %<>%
    select(-demographic_distribution,
           -region_distribution)
  # flatten so "impressions" and "spend" are no more data frames
  data %<>%
    jsonlite::flatten()
  return(data)
}

files <- fs::dir_info("input/ignore/results") 
# compute md5 sums
files %<>%
  mutate(md5 = tools::md5sum(path)) %>% 
  # extract scrape_date
  mutate(scrape_date = ymd_hms(str_extract(path, "\\d{4}-\\d{2}-\\d{2}\\s(\\d|:|_)*")))

# only keep youngest version
files %<>% 
  group_by(md5) %>% 
  # take date and time
  arrange(desc(scrape_date)) %>% 
  slice(1) %>% 
  ungroup() %>% 
  arrange(size) %>% 
  select(path, scrape_date)

files %>% 
  pwalk(function(...){
    file <- tibble(...)
    # scrape_date <- str_extract(file, "\\d{4}-\\d{2}-\\d{2}\\s(\\d|:|_)*")
    x <- load(file$path)
    data <- get(x)
    # if(file$path == "input/ignore/results/15733998334_2019-09-24 01:24:31.RData"){
    #   browser()
    # }
    scrape_date <- file$scrape_date
    # there are two different types of data formats we have to deal with
    # if it is a list (as of 2019-09-07)
    if (class(data) == "list"){
      # columns are already corrected
      data_in_list <- data %>% 
        map_df(function(data_frame){
          # add unique id
          return(process_data(data_frame, scrape_date))
        })
      # add to global variable
      ads <<- ads %>%
        bind_rows(data_in_list) 
      # if it is a data frame (before)
    } else {
      # fill up missing columns, so every dataframe has the same
      # columns
      current_names <- unique(names(data))
      missing_names <- setdiff(distinct_variables, current_names)
      missing_names %>% 
        walk(function(missing_name){
          data[missing_name] <<- NA
        })
      # add to global variable
      ads <<- ads %>% 
        bind_rows(process_data(data, scrape_date))
    }
  }
  )
gc()

# add page ids of national parties
pages <- read_csv("input/pages.csv") %>% 
  filter(!is.na(`Page ID`))

# set correct types
convert_datetime <- function(col){
  return(with_tz(ymd_hms(col, tz = "UTC"), 
                 "Europe/Zurich"))
}
ads %<>%
  mutate(
    page_name = as.factor(page_name),
    page_id = as.factor(page_id),
    funding_entity = as.factor(funding_entity),
    currency = as.factor(currency)
  ) %>% 
  mutate_at(vars(matches("time$")), convert_datetime) %>% 
  mutate(scrape_date = ymd_hms(scrape_date)) %>% 
  mutate_at(vars(matches("bound$")), as.integer)

dem_dist %<>%
  mutate(
    percentage = as.numeric(percentage),
    age = as.factor(age),
    gender = as.factor(gender)
  )

reg_dist %<>%
  mutate(
    percentage = as.numeric(percentage),
    region = as.factor(region)
  )

ads %<>%
  arrange(desc(scrape_date))

# strip access token from url
ads %<>%
  mutate(ad_snapshot_url = 
           str_replace(ad_snapshot_url, "(&access_token=.*)", ""))

# remove (obvious) duplicates (=where nothing has changed)
# only the latest scrape date will be kept
ads %<>%
  distinct(
    page_name, 
    page_id,
    funding_entity,
    ad_creation_time,
    ad_delivery_start_time,
    ad_delivery_stop_time,
    ad_creative_body,
    ad_creative_link_caption,
    ad_creative_link_title,
    ad_snapshot_url,
    currency,
    ad_creative_link_description,
    impressions.lower_bound,
    impressions.upper_bound,
    spend.lower_bound,
    spend.upper_bound,
    .keep_all = TRUE
  )

# extract unique ads
unique_ads <- ads %>% 
  distinct(
    page_name, 
    page_id,
    funding_entity,
    ad_creation_time,
    ad_delivery_start_time,
    ad_creative_body,
    ad_creative_link_caption,
    ad_creative_link_title,
    ad_snapshot_url,
    currency,
    ad_creative_link_description
  ) %>% 
  mutate(ad_uuid = row_number())

# join back so ad_uuid is in ads
ads %<>% 
  left_join(unique_ads)

# connect pages
ads %<>%
  mutate(page_id = as.numeric(as.character(page_id))) %>% 
  left_join(pages, by = c("page_id" = "Page ID")) %>% 
  mutate_at(vars(Kanton:`Account-Art`), as.factor) %>% 
  select(-Name, -`Link zu Page`, -`Link zu Transparenzpage`, -X9)


# fix impressions
ads %<>%
  mutate(impressions.lower_bound = 
           ifelse(is.na(impressions.lower_bound), 
                  1000000, 
                  impressions.lower_bound),
         impressions.upper_bound = 
           ifelse(is.na(impressions.upper_bound), 
                  1000000, 
                  impressions.upper_bound))

rm(pages, unique_ads)
gc()
# save ads df
save(ads, file = "input/ignore/tmp/ads.RData")
rm(ads)
print("wrote ads")
gc()
save(dem_dist, file = "input/ignore/tmp/dem_dist.RData")
rm(dem_dist)
print("wrote dem_dist")
gc()
save(reg_dist, file = "input/ignore/tmp/reg_dist.RData")
rm(reg_dist)
print("wrote reg_dist")
gc()
