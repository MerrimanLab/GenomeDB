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
	ON [dbo].[fact_gwas] (dataset) include (trait, pop);
