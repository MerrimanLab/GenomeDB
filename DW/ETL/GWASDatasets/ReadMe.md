# GWAS Dataset ETL process  

The process for loading new GWAS datasets is far more adhoc than that for the GTEx data. I considered trying to standardise the GWAS data files so that they
all had the same columns etc, but then I thought if we are going to have to wrangle the data anyway - we might as well do this directly in SQL. 
So, the process shall be: (manually) load the data into a staging area and then manually wrangle this into fact_gwas. I will save SQL scripts for each dataset in thi directory.

## Prerequisites  

The only prerequisite is that the GWAS data is mapped to hg19 (build 37) of the reference genome. Some datasets have {RSID, A1, A2} consistent with dbSNP147, build 37. Other datasets acutally have {CHR, POS} consistent with hg19 - these are even better.

## Recommendations  

Strongly recommend defining the column types to match the DW types when bulk loading the GWAS files. This will speed up the subsequent wrangling, prevent issues with joins on BLOBs (i.e. nvarchar(max)), and prevent truncation.
## Notes  

One dataset (to date anyway), Pattaro eGFRcrea_AfricanAmerican *does not* have {CHR, POS}, instead has {RSID, A1, A2} and these are based on build 36. I will load this, trying to merge these 3 columns with dbSNP147 - but will be a best effort only.
