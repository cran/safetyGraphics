#' Compare a settings object with a specified data set
#'
#' This function returns a list describing the validation status of a data set for a specified data standard
#'
#' This function returns a list describing the validation status of a settings/data combo for a given chart type. This list can be used to populate status fields and control workflow in the Shiny app. It could also be used to manually QC a buggy chart. The tool checks that all setting properties containing "_col" match columns in the data set via \code{checkColumnSettings},  and all properties containing "_values" match fields in the data set via \code{checkFieldSettings}.
#'
#' @param data A data frame to check against the settings object
#' @param settings The settings list to compare with the data frame.
#' @param charts  The charts being validated
#' @return
#' A list describing the validation state for the data/settings combination. The returned list has the following properties:
#' \itemize{
#' \item{"valid"}{ - boolean indicating whether the settings/data combo is valid for all charts}
#' \item{"status"}{ - string summarizing the validation results}
#' \item{"charts"}{ - a list of lists specifying whether each chart is valid. Each item in the list has "chart" and "valid" properties}
#' \item{"checkList"}{ - list of lists giving details about checks performed on individual setting specifications. Each embedded item has the following properties:}
#' \itemize{
#'\item{"key"}{ - list specifying the position of the property being checked. For example, `list("group_cols",1,"value_col")` corresponds to `settings[["group_cols"]][[1]][["value_col"]]`}
#' \item{"text_key"}{ - list from `key` parsed to character with a "--" separator.}
#' \item{"value"}{ - value of the setting}
#' \item{"type"}{ - type of the check performed.}
#' \item{"description"}{ - description of the check performed.}
#' \item{"valid"}{ - boolean indicating whether the check was passed}
#' \item{"message"}{ - string describing failed checks (where `valid=FALSE`). returns an empty string when `valid==TRUE`}
#'}
#'}
#'
#' @examples
#' testSettings <- generateSettings(standard="adam")
#' validateSettings(data=adlbc, settings=testSettings)
#' # .$valid is TRUE
#' testSettings$id_col <- "NotAColumn"
#' validateSettings(data=adlbc, settings=testSettings)
#' # .$valid is now FALSE
#'
#' @export
#' @import dplyr
#' @importFrom tibble tibble
#' @importFrom purrr map map_lgl map_dbl map_chr
#' @importFrom magrittr "%>%"
#' @importFrom rlang .data


validateSettings <- function(data, settings, charts=NULL){
  # load chart metadata (use custom data if available)
  chartmeta<-safetyGraphics::chartsMetadata
  if(!(is.null(options('sg_chartsMetadata')[[1]]))){ #if the option exists
    if(options('sg_chartsMetadata')[[1]]){ #and it's true
      chartmeta<-options('sg_chartsMetadata_df')[[1]] #use the custom metadata
    }
  }

  #initialize shell settings
  settingStatus<-list()

  # if no charts are specified, use all available
  if (is.null(charts)){
    charts <- chartmeta$chart
  }

  # Check that all required parameters are not null
  requiredChecks <- getRequiredSettings(charts = charts) %>% purrr::map(checkRequired, settings = settings)

  #Check that non-null setting columns are found in the data
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

  columnChecks <- dataKeys %>% purrr::map(checkColumn, settings=settings, data=data)

  #Check that non-null field/column combinations are found in the data
  fieldChecks <- NULL
  allKeys <- getSettingsMetadata(charts=charts, filter_expr = .data$field_mapping, cols = c("text_key","setting_type"))
  if (!is.null(allKeys)){
  fieldKeys <- allKeys %>% filter(.data$setting_type!="vector")%>% pull(.data$text_key)%>%textKeysToList()

  #Add items in vectors to list individually
  fieldVectorKeys <- allKeys %>% filter(.data$setting_type=="vector")%>% pull(.data$text_key)%>%textKeysToList()
  for(key in fieldVectorKeys){
    current<-getSettingValue(key, settings=settings)
    if (length(current) > 0 ) {
      for (i in 1:length(current)){
        newKey <- key
        newKey[[1+length(newKey)]]<-i
        fieldKeys[[1+length(fieldKeys)]]<-newKey
      }
    }
  }
  fieldChecks <- fieldKeys %>% purrr::map(checkField, settings=settings, data=data )
  }

  #Check that settings for mapping numeric data are associated with numeric columns
  numericChecks <- NULL
  numericKeys <- getSettingsMetadata(charts=charts, filter_expr=.data$column_type=="numeric", cols="text_key")
  if (!is.null(numericKeys)){
    numericChecks <- numericKeys %>%textKeysToList() %>% purrr::map(checkNumeric, settings=settings, data=data )
  }

  #Combine different check types in to a master list
  settingStatus$checks <-c(requiredChecks, columnChecks, fieldChecks, numericChecks) %>% {
    tibble(
      key = map(., "key"),
      text_key = map_chr(., "text_key"),
      type = map_chr(., "type"),
      description= map_chr(., "description"),
      value = map_chr(., "value"),
      valid = map_lgl(., "valid"),
      message = map_chr(., "message")
    )
  }

  #valid=true if all checks pass, false otherwise
  settingStatus$valid <- settingStatus$checks%>%select(.data$valid)%>%unlist%>%all

  #assess validity for each specified chart
  settingStatus$charts <- list()
  for(chart in charts){
    if(settingStatus$valid){
      settingStatus$charts[[chart]]<-TRUE
    }else{
      chart_keys <- getSettingsMetadata(charts=chart, cols ="text_key")
      valid <- settingStatus$checks%>%
        filter(.data$text_key %in% chart_keys)%>%
        select(.data$valid)%>%
        unlist%>%
        all
      settingStatus$charts[[chart]]<-valid
    }
  }

  #create summary string
  failCount <- nrow(settingStatus$checks%>%filter(!.data$valid))
  checkCount <- nrow(settingStatus$checks)
  settingStatus$status <- paste0(failCount," of ",checkCount," checks failed.")
  return (settingStatus)
}
