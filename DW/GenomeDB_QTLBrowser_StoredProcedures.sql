/* 
 * GenomeDB QTL BRowser Stored Procedures
 * Data warehouse for the storage of genome-wide summary datasets
 *
 * Stored Procedures which support data access from the QTL Browser.
 * Majority of data access logic encoded in stored procedures to make it easier to optimise.
 *
 * Created: 10 October, 2016
 * Nick Burns
 *
*/
USE [GenomeDB]
go

/*
 * gwas_dataset_info
 *   returns distinct dataset, trait, population information for GWAS data
*/
if exists (	select 1 from sys.sysobjects where name = 'gwas_dataset_info' and xtype = 'P') 
	drop procedure [dbo].[gwas_dataset_info];
go
create procedure [dbo].[gwas_dataset_info] 
as
begin
	with gwas_data as (
		select distinct dataset, trait, pop 
		from fact_gwas
	)
	select distinct 
		T.trait, D.dataset_name, P.pop
	from gwas_data G
		inner join dim_trait T on T.trait_id = G.trait
		inner join dim_dataset D on D.dataset_id = G.dataset
		inner join dim_population P on P.pop_id = G.pop;
end;
go

/*
 * get_gwas_region
 *     returns GWAS data for a given target (RSID or gene), trait, dataset  
 *     Multiple-dataset queries to be implemented via R, as individual queries
 *     concatentated using rbindlist.
*/
if exists (select 1 from sys.sysobjects where name = 'get_gwas_region' and xtype = 'P')
	drop procedure dbo.get_gwas_region;
go
create procedure dbo.get_gwas_region
	@feature nvarchar(64),
	@trait nvarchar(32),
	@dataset nvarchar(32),
	@delta int = 1500000
as
begin

    -- the CTE, feature, will return a single row giving the genomic coordinates
	-- of the user-supplied parameter @feature. If a gene is supplied, then the gene
	-- coordinates are returned and vice cersa if a RSID is supplied.
	with feature as (
		select chromosome, gene_start as 'start_position', gene_end as 'end_position'
		from dim_gene
		where gene_symbol = @feature

		union 

		select chromosome, position as 'start_position', position as 'end_position'
		from dim_snp
		where rsid = @feature
	)
	select F.chromosome, S.position, S.rsid, G.pvalue, G.beta, @trait as 'trait', @dataset as 'dataset'
	from fact_gwas G
		inner join dim_snp S on S.snp_id = G.snp_id
		inner join dim_trait T on T.trait_id = G.trait
		inner join dim_dataset D on D.dataset_id = G.dataset
		inner join feature F on F.chromosome = S.chromosome
	where T.trait = @trait
	  and D.dataset_name = @dataset
	  and S.position between F.start_position - @delta and F.end_position + @delta;
end;
go

/*
 * get_qtl_region
 *     returns QTL data for a given gene / tissue
 *     Multiple-tissue queries to me implemented via R
 *     by calling separate queries per tissue and combining via rbindlist
*/
if exists (select 1 from sys.sysobjects where name = 'get_qtl_region' and xtype = 'p')
	drop procedure dbo.get_qtl_region;
go
create procedure dbo.get_qtl_region
	@gene nvarchar(32),
	@tissue nvarchar(512),
	@dataset nvarchar(32)
as
begin
	select G.gene_symbol, T.smts, S.chromosome, S.position, S.rsid, Q.pvalue, Q.beta, @dataset as 'dataset'
	from fact_qtl Q
		inner join dim_gene G on G.gene_id = Q.gene
		inner join dim_snp S on S.snp_id = Q.snp
		inner join dim_tissue T on T.tissue_id = Q.tissue
		inner join dim_dataset D on D.dataset_id = Q.dataset
	where G.gene_symbol = @gene
	  and T.smts = @tissue
	  and D.dataset_name = @dataset
end;
go

/*
 * get_genes
 *     returns genes within a region
*/
if exists (select 1 from sys.sysobjects where name = 'get_genes' and xtype = 'p')
	drop procedure dbo.get_genes;
go
create procedure dbo.get_genes
	@chromosome tinyint,
	@start int,
	@end int
as
begin
	select chromosome, gene_symbol, gene_start, gene_end
	from dim_gene
	where gene_biotype = 'protein_coding'
	  and chromosome = @chromosome
	  and (    (gene_start between @start and @end)
	        or (gene_end between @start and @end)
			or (gene_start < @start and gene_end > @end) );
end;
go