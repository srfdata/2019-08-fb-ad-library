# R version 3.6.1
# Packages as of 2019-08

# setwd
setwd('~/bots/2019-08-fb-ad-library/analysis/')
LOCAL <- FALSE 

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
if(!LOCAL){
  if(!require(mailR)) {
    install.packages('mailR', repos='http://cran.us.r-project.org')
    require(mailR)
  }
}
load_dot_env('.env')
sendMail <- function(message) {
  if(!LOCAL){
    sender <- Sys.getenv('SRFDATA_MAIL_USER')
    recipients <- c(Sys.getenv('SRFDATA_MAIL_REC'))
    
    send.mail(
      from = sender,
      to = recipients,
      subject='Ad Library API Bot',
      body = message,
      encoding = 'utf-8',
      smtp = list(
        host.name = Sys.getenv('SRFDATA_MAIL_SMTP'),
        port = 465,
        user.name=sender,
        passwd=Sys.getenv('SRFDATA_MAIL_PASS'),
        ssl=TRUE
      ),
      authenticate = TRUE, send = TRUE
    )} else {
      # print(glue::glue('would be sending mail now with message "{message}"...'))
    }
}

SEARCH_EXPRESSIONS <- c('CVP', 'PDC', 'PPD', 'PCD',
                        'FDP', 'PLR', 'PLD',
                        'GLP', 'PVL', 'Grünliberale', 'vert\'libéral', 
                        'Verde Liberale', 'Verda-Liberala',
                        'SVP', 'UDC',
                        'Grüne Schweiz', 'GPS', 'Parti écologiste suisse', 
                        'Verts suisse', 'Partito ecologista svizzero', 
                        'Partida ecologica svizra',
                        'SP Schweiz', 'SP', 'PS',
                        'BDP', 'PBD'
)

# add page ids of national parties
pages <- read.csv('input/pages.csv')
pages <- pages[!is.na(pages$Page.ID),]
SEARCH_EXPRESSIONS <- c(SEARCH_EXPRESSIONS, pages$Page.ID)


FB_ACCESS_TOKEN = Sys.getenv('FB_ACCESS_TOKEN')
FB_URL = 'https://graph.facebook.com/v3.3/ads_archive' # base URL
FB_AD_TYPE = 'POLITICAL_AND_ISSUE_ADS'

LIMIT_PER_PAGE = 500 # how many results per page
SLEEP = 30 # seconds to sleep between requests

# queries the API and returns a json object with the respone if no error has occured
query_api <- function(url, params = NULL){
  Sys.sleep(SLEEP)
  
  if(!is.null(params)){
    res <- httr::GET(url,
                     query = params)
  } else {
    res <- httr::GET(url)
  }
  if(httr::http_type(res) != 'application/json'){
    stop(glue::glue('Response type not application/json'))
  }
  res_json <- jsonlite::fromJSON(httr::content(res, 'text', 
                                               encoding = 'UTF-8'))
  # res_json$data contains the response
  if(!is.null(res_json$error)){
    stop(glue::glue('Error in res_json: {res_json$error$message}'))
  }
  return(res_json)
}

# loop over all search expressions
empty <- sapply(SEARCH_EXPRESSIONS, function(search_expression){
  # check whether search_expression is a page id:
  IS_PAGE_ID <- FALSE
  if(grepl('^[0-9]*$', search_expression)){
    IS_PAGE_ID <- TRUE
  }
  # print(glue::glue("searching for {search_expression}"))
  tryCatch({
    query_params <- list(access_token = FB_ACCESS_TOKEN,
                         ad_reached_countries = '["CH"]',
                         ad_active_status = 'ALL', # default is ACTIVE,
                         limit = LIMIT_PER_PAGE, # according to https://disinfo.quaidorsay.fr/en/facebook-ads-library-assessment#incomplete-api-documentation and https://adtransparency.mozilla.org/eu/methods/
                         fields = '["page_name", 
                           "page_id", 
                           "funding_entity",
                           "ad_creation_time",
                           "ad_delivery_start_time",
                           "ad_delivery_stop_time",
                           "ad_creative_body",
                           "ad_creative_link_caption",
                           "ad_creative_link_description",
                           "ad_creative_link_title",
                           "ad_snapshot_url",
                           "demographic_distribution",
                           "region_distribution",
                           "impressions",
                           "spend",
                           "currency"]')
    if(IS_PAGE_ID){
      query_params['search_page_ids'] <- search_expression
    } else {
      query_params['search_terms'] <- search_expression
    }
    
    # assume next page for a start
    has_next_page <- TRUE
    next_page <- NULL
    answer_data <- list()
    cur_page <- 0
    while(has_next_page){
      cur_page <- cur_page + 1
      # query page
      if(is.null(next_page)){
        # print(glue::glue("first page"))
        # first page
        answer_json <- query_api(FB_URL, query_params)
      } else {
        # print(glue::glue("subsequent page"))
        # any following page
        answer_json <- query_api(next_page)
      }
      # parse answer
      if(is.null(nrow(answer_json$data))){
        # results; break
        # print(glue::glue("no results for {search_expression}"))
        return(NULL)
      }
      if(nrow(answer_json$data) > 0){
        # if returned data has the maximum number of results per page
        if(nrow(answer_json$data) >= LIMIT_PER_PAGE){
          has_next_page <- TRUE
          next_page <- answer_json$paging[["next"]]
        } else {
          # stop condition
          # print(glue::glue("last page will be reached"))
          has_next_page <- FALSE
        }
        # print(glue::glue("number of rows {nrow(answer_json$data)}"))
        
        cur_data <- answer_json$data
        # add search expression
        cur_data$search_expression <- search_expression
        # concatenate
        # watch out - for some very unimaginable reason (bad will?), the API might
        # return not the same amount of fields in each page, this has to be fixed here
        if(!is.null(next_page)){
          all_fields <- c(
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
          cur_fields <- unique(names(cur_data))
          missing_fields <- setdiff(all_fields, cur_fields)
          for(i in missing_fields) {
            cur_data[[i]] <- NA
          }
        }

        answer_data[[cur_page]] <- cur_data
        # print(glue::glue("number of rows in answer_data {nrow(answer_data)}"))
      }
    }

    # print(glue::glue("queried all pages"))
    data <- answer_data
    # save everything
    save(data, file = 
           glue::glue('input/ignore/results/{search_expression}_{Sys.time()}.RData'))
  }, error = function(e){
    sendMail(glue::glue('Fehler: {e$message}'))
  }, warning = function(w){
    sendMail(glue::glue('Warnung: {w$message}'))
  }
  )
})


