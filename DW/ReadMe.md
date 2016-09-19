# GenomeDB Documentation  

## Genomic Coordinate System  

We are in the process of standardising the genomic coordinate system used by GenomeDB. All coordinates will be based on the 1000 Genomes Project and thus, will conform to the human reference genome (GRCh37, hg19) and match dbSNP147.  

dbSNP147 will form the base coordinate system. All input datasets will need to conform to this reference.

## Creating the data warehouse schema  

more...


## Populating the references tables  

The following reference tables may be pre-populated:  

  - dim_snp (based on dbSNP147)  
  - dim_coordinate (based on dbSNP147)  
  - dim_gene (based on the GTEx metadata file)  

Scripts to prepopulate the data warehouse are currently in development.  

## Loading new data  

Loading new data requires that raw input files are first processed to match GRCh37 coordinates and dbSNP147 RSIDs.

ETL scripts are currently in development.  

## Future work  

TBC


