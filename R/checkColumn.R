#' Check that a setting parameter has a matching data column
#'
#' Checks that a single parameter from the settings list matches a column name in a specified data set
#'
#' This function compares settings with column names as part of the \code{validateSettings()} function. More specifically, the function checks whether the \code{key} in a \code{settings} object matches a column in  \code{"data"}.
#'
#' @param key a list (like those provided by \code{getSettingKeys())} defining the position of parameter in the settings object.
#' @param settings The settings list used to generate a chart like \code{eDISH()}
#' @param data A data frame to check for the specified column
#' @return A list containing the results of the check following the format specified in \code{validateSettings()[["checkList"]]}
#'
#'
#' @examples
#' testSettings<-generateSettings(standard="AdAM")
#' testSettings$filters<-list()
#' testSettings$filters[[1]]<-list(value_col="RACE",label="Race")
#' testSettings$filters[[2]]<-list(value_col=NULL,label="No Column")
#' testSettings$filters[[3]]<-list(value_col="NotAColumn",label="Invalid Column")
#'
#' #pass ($valid == TRUE)
#' safetyGraphics:::checkColumn(key=list("id_col"),
#'                                     settings=testSettings, adlbc)
#'
#' #pass
#' safetyGraphics:::checkColumn(key=list("filters",1,"value_col"),
#'                                     settings=testSettings, adlbc)
#'
#' #NULL column pass
#' safetyGraphics:::checkColumn(key=list("filters",2,"value_col"),
#'                                     settings=testSettings, adlbc)
#'
#' #invalid column fails
#' safetyGraphics:::checkColumn(key=list("filters",3,"value_col"),
#'                                     settings=testSettings, adlbc)
#' @keywords internal

checkColumn <- function(key, settings, data){
  stopifnot(typeof(key)=="list",typeof(settings)=="list")

  current <- list(key=key)
  current$text_key <-  paste( unlist(current$key), collapse='--')
  current$type <- "column"
  current$description <- "column parameter from setting setting found in data?"
  current$value <- getSettingValue(key=key,settings=settings)
  if(is.null(current$value)){
    current$value <- "--No Value Given--"
    current$valid <- TRUE
    current$message <- ""
    return(current)
  }else{
    current$valid <- hasColumn(current$value, data)
    current$message <- ifelse(current$valid,"",paste0(current$value," column not found in data."))
    return(current)
  }
}
