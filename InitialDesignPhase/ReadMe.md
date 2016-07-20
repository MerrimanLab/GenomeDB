# GenomeDB  
## Initial Design Brief  

### Purpose  
To develop a highly abstract database schema suitable for the storage and retrieval of genome-level summary statistics. For example, GenomeDB should be able to store summary datasets from genome-wide association studies, eQTL and gene expression experiments, DNaseI hypersensitivity peaks, histone markers etc. The schema should be suitably generic that these various datasets may be stored seemlessly, without requiring significant schema modifications to cater for new datasets. 

The schema should support user queries which span all datasets for a given region of the genome. For example, a user who is interested in the expression of the BRCA1 gene, should be able to obtain a quick summary of the BRCA1 region across all datasets (e.g. locus zoom-like summaries of GWAS, QTL and rgulatory peaks related to the BRCA1 locus). The design should be sufficiently optimised to allow interactive and visual exploration of genomic regions.

### Defining the data 

Ignoring the biological context, then all genome-wide summary datasets may be defined by a genomic coordinate (chromosome, start, end) and a test statistic. We will refer to a set of genomic coordinates as a region, and the test statistic as a z-score throughout this project.

__Genomic regions__  
A genomic region may be described by a chromosome, a start and an end position (chr, start, end). This definition is sufficient to accurately describe genes, regulatory peaks, SNPs, indels and so forth. 

Regions may have additional attributes such as a gene name, an RSID, or information about relevant alleles. This information needs to be captured. Additionally, in the case of genes, additional information such as the gene biotype (protein-coding, RNA, psuedogene etc.) should be recorded.

A region may be represented in many datasets (e.g. a SNP may have a z-score in many GWAS datasets, or a 250 bp window might have z-scores for a variety of regulatory elements). Thus, the *context* in which a region has been studied needs to be modeled separately from the definition of the region itself. We suggest that the context is perhaps better attributed to the z-score than to the region.

We assume that a region is not directly associated with a study or a trait. That this association is specific to a z-score and not a genomic region.

__z-scores__  
Test statistics are defined by a genomic region, and are intrinsically associated with some biological context. For example, GWAS summary statistics are specific to the trait being studied. Gene expression and eQTL data are tissue-specific.

__metadata__  
In addition to regions and zscores, it is sensible to also record information about the source of the data, the study from which the data originated, the size of the study etc. This information may be relevant for the aggregation and summarisation of the data. 

The type of metadata which is recorded may vary from one source to another. This may be a good opportunity to explore the incorporation of document storage, or flexible schema models.

