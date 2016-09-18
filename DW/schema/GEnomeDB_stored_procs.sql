/* 
 * GenomeDW Sproc Defintion script
 * Data warehouse for the storage of genome-wide summary datasets
 *
 * Stored Procedure Definitions
 * ----------------------------
 *   - 
 *
 * Created: 4 August, 2016
 * Edits:
 *
*/

USE [GenomeDB]
go

if exists (select 1 from sys.objects where type = 'FN' and name = 'udf_parse')
	drop function dbo.udf_parse;
go
create function dbo.udf_parse(@string nvarchar(max), @delim nvarchar(max), @nth_element int)
RETURNS nvarchar(max)
AS
BEGIN
    declare 
		@left nvarchar(max),
		@right nvarchar(max) = @string,
		@length int = len(@string),
		@next_position int = 1

	while @nth_element > 0
	begin
		set @next_position = charindex(@delim, @right)

		set @left = substring(@right, 1, @next_position - 1)
		set @right = substring(@right, @next_position + 1, @length)

		set @length = len(@right)
		set @nth_element = @nth_element - 1
	end

	return @left
END;
go
/* Examples:
 *    select dbo.udf_parse('help_me_parse_a_string', '_', 3)
 *    select dbo.udf_parse('ENS12345.01', '.', 1)
*/


if exists (select 1 from sys.objects where type = 'P' and name = 'sproc_parse_qtl')
	drop procedure dbo.sproc_parse_qtl;
go
create procedure dbo.sproc_parse_qtl
	@tissue int,
	@datasource int
AS
BEGIN
	insert into stage.qtl (ensembl_id, chromosome, position, A1, A2, tissue, dataset, beta, tstat, pvalue)
	select
		dbo.udf_parse(ensembl_id, '.', 1),
		dbo.udf_parse(snp_id, '_', 1),           
		dbo.udf_parse(snp_id, '_', 2),
		dbo.udf_parse(snp_id, '_', 3),
		dbo.udf_parse(snp_id, '_', 4),
		tissue = @tissue,
		dataset = @datasource,
		beta, 
		tstat,
		pvalue
	from stage.preqtl;
END;
go


if exists (select 1 from sys.objects where type = 'P' and name = 'unstage_qtl')
	drop procedure dbo.unstage_qtl;
go
create procedure dbo.unstage_qtl
	@tissue int,
	@datasource int
AS
BEGIN

    begin tran;
	insert into dbo.fact_qtl (gene, tissue, dataset, snp_position, A1, A2, beta, pvalue)
	select
		G.gene_id,
		@tissue,
		@datasource,
		Q.position,
		Q.A1,
		Q.A2,
		Q.beta,
		Q.pvalue
	from stage.qtl as Q
		inner join dbo.dim_gene as G on g.ensembl_id = Q.ensembl_id;
	commit;
END;
go

if exists (select 1 from sys.objects where type = 'P' and name = 'unstage_expression')
	drop procedure dbo.unstage_expression;
go
create procedure dbo.unstage_expression
	@tissue tinyint,
	@dataset tinyint

AS
BEGIN
	update stage.expression
	set ensembl_id = dbo.udf_parse(ensembl_id, '.', 1);

	insert into dbo.fact_expression
	select
		G.gene_id,
		@tissue,
		@dataset,
		E.rpkm
	from stage.expression as E
		inner join dbo.dim_gene as G on G.ensembl_id = E.ensembl_id;
		
END;
go

if exists (select 1 from sys.objects where type = 'P' and name = 'unstage_gwas')
	drop procedure dbo.unstage_gwas;
go
create procedure dbo.unstage_gwas
AS
BEGIN
	select 1;
END;
go

if exists (select 1 from sys.objects where type = 'P' and name = 'reset_staging')
	drop procedure dbo.reset_staging;
go
create procedure stage.reset_staging
AS
BEGIN
	truncate table stage.expression;
	truncate table stage.qtl;
	--truncate table stage.gwas;
	truncate table stage.meta;
	truncate table stage.gene;
END;
go


/*
 * Interface / Analytical Queries
 *
*/


/*
 * Get top 5 tissues, for gene G, ranked by min pvalue
 *
*/

if exists (select 1 from sys.objects where type = 'P' and name = 'get_by_top_tissues')
	drop procedure dbo.get_by_top_tissues;
go
create procedure dbo.get_by_top_tissues @gene nvarchar(max)
AS
BEGIN
	with tissue_rank as (
		select T.smts, F.tissue as TissueID, min(pvalue) as TissueScore, rank() over (order by min(pvalue) asc) as TissueRank
		from fact_qtl as F
			inner join dim_gene as G on G.gene_id = F.gene
			inner join dim_tissue as T on T.tissue_id = F.tissue
		where G.gene_symbol = @gene
		group by T.smts, F.tissue
	)
	select 
		G.gene_symbol,
		T.smts,
		F.snp_position,
		F.pvalue,
		T.TissueRank,
		T.TissueScore
	from fact_qtl F
		inner join dim_gene G on G.gene_id = F.gene
		inner join tissue_rank as T on T.TissueID = F.tissue
	where G.gene_symbol = @gene
	  and T.TissueRank < 7
	order by T.TissueRank asc, F.snp_position asc;
END;
go


/*
 * GWAS query. Extracts a GWAS region, given a target gene or target SNP
 *
*/
if exists (select 1 from sys.objects where type = 'P' and name = 'get_gwas_region')
	drop procedure dbo.get_gwas_region;
go
create procedure dbo.get_gwas_region @lcl_feature nvarchar(max), @lcl_trait nvarchar(max)
as
begin

    -- feature: the target feature the user is interested in, i.e. a SNP or gene
	--          this cte should only ever return 1 row. Where a user is interested in a gene, 
	--          the SNP union will be NULL and vice versa
	with feature as (
		select C.coord, C.chromosome, C.center_pos
		from dim_gene G
			inner join dim_coordinate C on C.coord = G.coord
		where gene_symbol = @lcl_feature

		union 

		select C.coord, C.chromosome, C.center_pos
		from dim_snp S 
			inner join dim_coordinate C on C.coord = S.coord
		where rsid = @lcl_feature
	)
	select C.coord, C.chromosome, C.center_pos, D.dataset_name as dataset, G.trait, S.rsid, G.pvalue
	from dim_coordinate C
		inner join feature F on F.chromosome = C.chromosome
		inner join fact_gwas G on G.coord = C.coord
		inner join dim_trait T on G.trait = T.trait_id
		inner join dim_dataset D on G.dataset = D.dataset_id
		inner join dim_snp S on S.coord = C.coord
	where T.trait = @lcl_trait
	  and C.center_pos between F.center_pos - 500000 and F.center_pos + 500000;
end;
go


/*
 *  Window-based scoring
 *  For a given dataset, partition the summary results into windows of
 *  a constant size (default 1 MB - note this is exploratory only)
 *  and score each window by the minimum pvalue. 
 *  Return the top K windows (default 20).
 *
 *  Examples:
 *    exec get_top_windows @dataset = 3;    -- runs with default window_size, returning top 20 windows
 *    exec get_top_windows @dataset = 3, @window_size = 500000, @top_k = 50; 
 *
 * NOTE: 
 *   I have run this on the Locke dataset (obesity) and cross referenced with their published results
 *   The FTO locus comes out as the top window :)
 *   All novel loci are also present in the top 50 results :)
 *   Good agreement then between this naive approach and the results we expected
*/
if exists (select 1 from sys.objects where type = 'P' and name = 'get_top_windows')
	drop procedure dbo.get_top_windows;
go
create procedure dbo.get_top_windows @dataset int, @window_size int = 1000000, @top_k int = 20
as
begin

    select top (@top_k)
		chromosome, 
		start_pos / @window_size as 'window', 
		min(pvalue) as 'score'
	from fact_gwas F
		inner join dim_coordinate C on C.coord = F.coord
	where dataset = @dataset and pvalue < 0.00005
	group by chromosome, start_pos / @window_size
	order by score asc;
end;
go

