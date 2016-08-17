# GenomeDB_Data_Logic.R
# GenomeDB
# 
# Contains functions for database access and data manipulation
#
# Nick BUrns
# August, 2016

# database()
# ODBC connection management. Usage:
#    db <- database()
#    db$connect_()
#    db$query_("select name from sys.tables;")
#    db$disconnect_()
database <- function () {
    
    conn <- NULL
    connection_string <- 'driver={SQL Server};
                          server=ORBITAL\\SQLDEVBOX;
                          trusted_connection=true;
                          database=GenomeDB;'
    
    # Returns a list of functions which can be used to manage the connection to GenomeDB
    list(
        connect_ = function () conn <<- RODBC::odbcDriverConnect(connection_string),
        disconnect_ = function () {RODBC::odbcClose(conn); conn <<- NULL},
        query_ = function (query) {RODBC::sqlQuery(conn, query)}
    )
}