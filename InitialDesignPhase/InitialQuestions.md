# GenomeDB - initial questions  

The purpose of the GenomeDB is to design a database schema which can store genome-scale summary datasets, for exmaple GWAS, QTL, gene expression or regulatory peaks. In this document, we will keep track of the various design questions relevant to the design and implementation of this database.

__individual genotype data__  
It may be possible to store individual genotype data alongside summary statistics. However, this will require a substantially different database design and will seriously increase the storage requirements. We question whether it is necessary, or relevant, to store genotype data. Primarily, the genome database will be about subsetting, summarisation and comparison of regions of the genome. IS there a use-case which would support the addition of genotpe data within the database, that could not be served by common PLINK workflows?

  1. Do we need to store individual genotype data in this database?  
  2. If so, please clearly define the use-case for genotype data.  
  3. For the use-cases above, would they benefit from an interactive, exploratory interface? Or do these use-cases describe a more focused investigation?  
  4. For the use-cases above, what advantage is there in having genotype data in a database (+ exploratory interface), versus common PLINK formats (and PLINK-based methods of analysis)?  


__typical questions__  
In order to build an interactive interface, the data storage will need to be optimised based on the common questions which users are likely to be interested in. Obvious questions may include:  

  - "are there differences in the GWAS profiles for region-X between studies A and B?"  
  - "what are the top 5 GWAS regions for diabetes in both studies A and B?"  
  - "are there significant eQTLs for gene-Y and if so, where are they?"  
  - "are there any significant GWAS hits within regulatory regions of gene-Y?"  

Please think carefully about other common questions and add these below.  


__datasets__  
The GenomeDB should cater for any genome-scale dataset defined by a genomic region and a z-score (e.g. GWAS, QTLs, regulatory peaks etc.). In addition to storing and querying the database, we will work towards creating an ETL (extract-transform-load) workflow for adding new datasets so that this database may evolve over time. 

Please think carefully about which datsets are the most critical to include in this initial phase:  

  1. GWAS:  
    - Kottgen,   
    - the most recent obesity & diabetes,  
    - lab specific GWAS summaries:   

  2. eQTL & gene expression:  
    - the GTEx datasets  
    - kidney eQTLs  
    - immune eQTLs (summary data not published that we are aware of)  

  3. Regulatory elements:  
    - DNaseI hypersensitivity peaks from ENCODE & epigenomics roadmap  
    - histone markers form epigenomics roadmap  

...
