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

**Post-import indexing.**  
TIME: approx. 2 hours  

Build the following indexes to improve query performance (essential for bulk load of QTL and GWAS data)  

```
create clustered index idx_snp_chromosome on dim_snp (chromosome);  
create nonclustered index idx_snp_mapping on dim_snp (chromosome)  
  include (position, A1, A2);
```

**Backup the database**  
TIME: approx 30 minutes


## Step 3: Importing GTEx datasets  

**PART 1: Tissue, Gene and QTL data**  

We have developed an SSIS package to do this. The workflow is shown below:  

![Image of SSIS ETL Workflow](./GTExETL/SSISDB_workflow.png)  



The package requires the following:  

  - **connection managers**: flat file connection managers for GTEx tissue metadata, GTEx gene data, GTEx QTL files. OLE DB connection manager pointing to GenomeDB on SQL Server.  
  - **input QTL data directory**: the ```for each``` container iterates over all QTL files in a named directory. You can configure this directory to be anywhere, but it should only contain QTL files that you want to load.  

We had initially created a very nice-looking, seemless workflow using a series of SSIS operations within a single data flow. However this performed *terribly*(!) due to the automatic parallel-staging of batches - just caused massive contention.

Ultimately, we developed a series of independent SQL tasks. This meant each operation (e.g. lookups of tissue, gene and snp ids) perform independently and in sequence. 

The same workflow could be scripted (say in R with an ODBC connection).

**TO DO (future work):**  
Add logging to the SSIS workflow to capture genes and snps which do not map. NOTE: with regards to genes, we have found the majority of Ensembl IDs which do not match are psuedogenes or non-coding RNAs.

**PART 2: Gene Expression data**  

This file is huge, 27 GB. Loading of this dataset included in the SSIS ETL package.  


## Step 4: Importing GWAS summary sets  

more

## Additional notes...  

more

