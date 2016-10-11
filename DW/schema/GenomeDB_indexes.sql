/* 
 * GenomeDB Indexing script
 * Data warehouse for the storage of genome-wide summary datasets
 *
 * Indexing Script
 * ---------------
 *   
 * GTEx QTLs, Expression and the majority of the GWAS datasets are now loaded.
 * At this stage, there are no indexes on the fact tables, and a minimal set of 
 * indexes on the dimension tables.
 *
 * Here, we will begin to build the indexes that will have the interface flying.
 *
 * Created: 7 October, 2016
 * Nick Burns
 *
*/
USE [GenomeDB]
go


-- Optimise [dbo].[gwas_dataset_info]
create nonclustered index idx_gwas_info
	ON fact_gwas (dataset) include (trait, pop);

/*
 * Indexes to optimise the sproc get_gwas_region
 * Initial run (no indexes) took 5 min, with table scans on dim_snp and fact_gwas dominating
 * Optimised to <<1 second
*/
-- Table scan of dim_snp on rsid is 70% of the cost on a 5 min query
create nonclustered index idx_snp_rsid
  on dim_snp (rsid, chromosome, position);

-- table scan of fact_gwas is 13 % of the cost on a 5 min query (prior to adding above index)
create nonclustered index idx_gwas
  on fact_gwas (snp_id, trait, dataset) include (pvalue);

/*
 * Indexes to optimise the sproc get_qtl_region
 * Initial run (no indexes) took 15 min, with a table scan on fact_qtl taking 90% of that.
 * Optimised to <<1 second
*/
create nonclustered index idx_qtls
	on fact_qtl (gene, tissue, snp, dataset) include (pvalue);


