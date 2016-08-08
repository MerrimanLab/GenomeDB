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
	@tissue tinyint,
	@datasource tinyint
AS
BEGIN
	update stage.qtl
	set
		ensembl_id = dbo.udf_parse(ensembl_id, '.', 1),
		chromosome = dbo.udf_parse(snp_id, '_', 1),           
		position = dbo.udf_parse(snp_id, '_', 2),
		A1 = dbo.udf_parse(snp_id, '_', 3),
		A2 = dbo.udf_parse(snp_id, '_', 4),
		tissue = @tissue,
		dataset = @datasource;
END;
go

if exists (select 1 from sys.objects where type = 'P' and name = 'unstage_qtl')
	drop procedure dbo.unstage_qtl;
go
create procedure dbo.unstage_qtl
AS
BEGIN
	insert into dbo.fact_qtl
	select
		G.coord,
		G.gene_id,
		Q.tissue,
		Q.dataset,
		Q.A1,
		Q.A2,
		Q.beta,
		Q.pvalue
	from stage.qtl as Q
		inner join dbo.dim_gene as G on g.ensembl_id = Q.ensembl_id
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