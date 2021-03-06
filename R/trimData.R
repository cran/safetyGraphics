#' Removes unnecessary rows and columns
#'
#' Removes unnecessary rows and columns from data based on current settings
#'
#' @param data a data frame to trim
#' @param settings the settings list used to determine which rows and columns to drop
#' @param charts the charts being created  Default: \code{NULL} (include data needed for all available charts).
#' @return A dataframe with unnecessary columns and rows removed
#'
#' @examples
#' testSettings <- generateSettings(standard="adam")
#' trimmed<-safetyGraphics:::trimData(data=adlbc, settings=testSettings)
#'
#' @importFrom dplyr filter
#' @importFrom purrr map
#' @importFrom rlang parse_expr .data
#'
#' @keywords internal


trimData <- function(data, settings, charts=NULL){

  ## Remove columns not in settings ##
  col_names <- colnames(data)

  allKeys <- getSettingsMetadata(charts=charts, filter_expr = .data$column_mapping, cols = c("text_key","setting_type"))
  dataKeys <- allKeys %>% filter(.data$setting_type !="vector") %>% pull(.data$text_key) %>% textKeysToList()

  # Add items in vectors to list individually
  dataVectorKeys <- allKeys %>% filter(.data$setting_type =="vector") %>% pull(.data$text_key) %>% textKeysToList()
  for(key in dataVectorKeys){
    current<-getSettingValue(key, settings=settings)
    if (length(current) > 0 ) {
      for (i in 1:length(current)){
        newKey <- key
        newKey[[1+length(newKey)]]<-i
        sub <- current[[i]]
        if(typeof(sub)=="list"){
          newKey[[1+length(newKey)]]<-"value_col"
        }
        dataKeys[[1+length(dataKeys)]]<-newKey
      }
    }
  }

  settings_values <- map(dataKeys, function(x) {return(getSettingValue(x, settings))})

  common_cols <- intersect(col_names,settings_values)

  data_subset <- select(data, unlist(common_cols))

  ## Remove rows if baseline or analysisFlag is specified ##
  baselineSetting<-settings[['baseline']][['value_col']]
  baselineMissing <- is.null(baselineSetting)
  analysisSetting<-settings[['analysisFlag']][['value_col']]
  analysisMissing <- is.null(analysisSetting)

  if(!baselineMissing | !analysisMissing) {

    # Create Baseline String
    baseline_string <- ifelse(!baselineMissing,
     paste(settings[['baseline']][['value_col']], "%in% settings[['baseline']][['values']]"),
     "")

    # Create AnalysisFlag String
    analysis_string <- ifelse(!analysisMissing,
      paste(settings[['analysisFlag']][['value_col']], "%in% settings[['analysisFlag']][['values']]"),
    "")

    # Include OR operator if both are specified
    operator <- ifelse(!baselineMissing & !analysisMissing, "|", "")

    # Create filter string and make it an expression
    filter_string <- paste(baseline_string, operator, analysis_string)
    filter_expression <- parse_expr(filter_string)

    #Filter on baseline and analysisFlag
    data_subset <-  filter(data_subset, !!filter_expression)

  }

  return(data_subset)
}
