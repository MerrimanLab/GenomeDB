# Browser_Logic.R
# GenomeDB
# 
# Contains flow / control logic relevant for the GenomeDB interface
# THis code file is a simple abstraction to simplify the server.R file
#
# Nick BUrns
# August, 2016

# browser_init()
# initialise the browser state
browser_init <- function () {
    stage <- 0
    
    list(
        forward = function () stage <<- stage + 1,
        backward = function () stage <<- stage - 1,
        get = function () stage
    )
}