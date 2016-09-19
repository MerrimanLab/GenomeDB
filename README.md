# GenomeDB
GenomeDB is a generic database schema for genome-wide summary datasets. The goal is to be able to provide a general abstraction suited to any form of genome analysis, for example GWAS, QTL, gene expression, regulatory peaks...

## GitHub  

This repository is under version control on GitHub. 
  
  - the master and devbranches are currently the most up-to-date  
  - as of 20 Sept, 2016, the sqlserver branch was entirely re-created and all existing scripts / files were removed. Am starting from scratch and going to tidy up this repository (including documentation)  

## dbSNP147 re-design (hg19)  

It is critical that all datasets are mapped to the same base coordinate system. This is essential to be able to merge / compare / contrast the datasets and to do things like calculate LD or perform more advanced joint analyses.  

We have decided on dbSNP Build 147 (human references genome GRCh37, hg19) as the base coordinate system.

This has the advatange that all 1000 Genomes variants are included in dbSNP147, which makes the LD calculation quite straightforward. There will however be some challenges in terms of lifting over older GWAS datasets (in particular, with trying to merge inconsistent RSIDs). This data integration will be a work in progress.  


