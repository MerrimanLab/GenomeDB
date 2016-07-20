# GenomeDB  
## Initial Design  

### Purpose:  
To develop a highly abstract database schema suitable for the storage and retrieval of genome-level summary statistics. For example, GenomeDB should be able to store summary datasets from genome-wide association studies, eQTL and gene expression experiments, DNaseI hypersensitivity peaks, histone markers etc. The schema should be suitably generic that these various datasets may be stored seemlessly, without requiring significant schema modifications to cater for new datasets. 

The schema should support user queries which span all datasets and which can quickly return the results from all datasets, for a given region of the genome. For example, a user who is interested in the expression of the BRCA1 gene, should be able to obtain a quick summary of the BRCA1 region across all datasets (e.g. locus zoom-like summaries of GWAS, QTL and rgulatory peaks related to the BRCA1 locus). The design should be sufficiently optimised to allow interactive and visual exploration of genomic regions.
