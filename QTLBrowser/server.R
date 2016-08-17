# eQTL Browser
# Server.R
#
# User interface to browse eQTL data.
# Nick Burns
# June 2016

library(shiny)
library(RODBC)
library(glida)
library(ggplot2)
library(data.table)
library(gridExtra)
source("eqtl_library.R")

# for testing only:
options(shiny.maxRequestSize=300*1024^2) 

shinyServer(function(input, output) {
    
    
})