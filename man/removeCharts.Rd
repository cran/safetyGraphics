% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/removeCharts.R
\name{removeCharts}
\alias{removeCharts}
\title{Remove a chart from the safetyGraphics shiny app}
\usage{
removeCharts(charts, settingsLocation = getwd())
}
\arguments{
\item{charts}{Name of the chart(s) to remove - one word, all lower case}

\item{settingsLocation}{path where the custom settings will be loaded/saved. If metadata is not found in that location, it will be read from the package (e.g. safetyGraphics::settingsMetadata), and then written to the specified location once the chart has been removed}
}
\description{
This function updates settings objects to remove chart from the safetyGraphics shiny app
}
\details{
This function makes it easy for remove a chart from the safetyGraphics shiny app by making updates to the underlying metadata used by the package.
}
