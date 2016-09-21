# Extract Transform Load (ETL) notes  

## Step 1: Wrangle dbSNP Build 147, hg19  
TIME: approx 30 minutes

dbSNP Build 37 (GRCh37, hg19) will be our core reference set with regards to genomic coordinates. A VCF containing all accepted variants was downloaded from dbSNP's ftp site (ftp://ftp.ncbi.nih.gov/snp/organisms/human_9606_b147_GRCh37p13/).  

To speed up the import into SQL Server, we will preprocess this file using awk:  

  - remove the header (rows beginning with #)  
  - recode X, Y and MT chromosomes to 23, 24, and 25 respectively  
  - remove the 6th column, retaining on CHR, POS, RSID, A1, A2  
  - make the file tab separated (note, A2 contains commas so cannot make the file comma separated  

```
bash $ awk '/!#/ \
            $1=="X" {$1=23} $1=="Y" {$1=24} $1=="MT" {$1=25} 1' \  
            <vcf_file> \ 
            | cut -f 1,2,3,4,5 \
            | tr " " "\t" > <output_file>
```

## Step 2: Import in SQL Server  
TIME: approx 5 hours  

We used SQL Server Data Import / Export tool to load the processed dbSNP file directly into GenomeDB.dbo.dim_snp. Nothing special required here, just a straight load.

Recommend dropping the clustered index on dim_snp prior to load for maximum efficiency. Then rebuild the clustered index post-import.


## Step 3: Importing GTEx datasets  

more

## Step 4: Importing GWAS summary sets  

more

## Additional notes...  

more

