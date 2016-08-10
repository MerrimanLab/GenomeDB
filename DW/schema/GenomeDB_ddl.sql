/* 
 * GenomeDW DDL script
 * Data warehouse for the storage of genome-wide summary datasets
 *
 * DDL Script
 * ----------
 *   - Section 1: Staging area
 *       tables: TBC
 *
 *   - Section 2: dimensions  
 *       tables: dim_coordinate, dim_gene, dim_tissue, dim_trait, dim_population, dim_dataset
 *
 *   - Section 3: fact (subject) areas
 *       tables: fact_gwas, fact_qtl, fact_expression
 * 
 *   - Stored procedures / functions
 *       etl procs:
 *       NOTE: stored queries (procedures, views,...) will be defined in another script
 *
 * Created: 3 August, 2016
 * Edits:
 *    3 August, 2016: created script, table DDL created. Nick Burns.
 *    8 August, 2016: updated all identity columns to INT type (tinyint resulted in arithmetic overflow on insert)
 *
*/
USE [GenomeDB]
go
-- NOTE: created via the GUI. 4 data files, 1 log file, set to simple recovery

/*
 * Section 1: Staging Area
 *     stage.qtl, stage.expression, stage.meta, stage.gene, stage.gwas
*/
if not exists (select 1 from INFORMATION_SCHEMA.SCHEMATA where schema_name = 'stage')
	exec sp_executesql N'create schema stage';
go

-- stage.qtl: landing table for bulk load of qtl data
-- due to a lack of native string split fx in SQL Server (pre 2016)
-- qtl has been pre-parsed using command line tools
if exists (
	select 1 
	from sys.tables as tbl
		inner join sys.schemas as sch on sch.schema_id = tbl.schema_id
	where tbl.name = 'qtl'
	  and sch.name = 'stage'
) drop table stage.qtl;
create table stage.qtl 
(
	ensembl_id nvarchar(32),
	chromosome tinyint,
	position int,
	A1 nvarchar(max),
	A2 nvarchar(max),
	genome_build char(3),
	beta float,
	tstat float,
	pvalue float
);
go
-- index for unstaging into fact_qtl
create clustered index idx_qtl_ens on stage.qtl (ensembl_id);
go


-- stage.expression
--   Landing table for bulk load of GTEx expression data
if not exists (
	select 1 
	from sys.tables as tbl
		inner join sys.schemas as sch on sch.schema_id = tbl.schema_id
	where tbl.name = 'expression'
	  and sch.name = 'stage'
)
create table stage.expression
(
	ensembl_id nvarchar(32),
	gene_symbol nvarchar(32),
	sample_id nvarchar(128),
	rpkm float
);
go

-- stage.meta
--   Landing table for bulk load of GTEx sample / tissue metadata
if not exists (
	select 1 
	from sys.tables as tbl
		inner join sys.schemas as sch on sch.schema_id = tbl.schema_id
	where tbl.name = 'meta'
	  and sch.name = 'stage'
)
create table stage.meta
(
	sample_id nvarchar(128),
	smts nvarchar(128),
	smtsd nvarchar(128)
);
go

-- stage.gene
--   Landing table for GTEx Expression Gene information
if not exists (
	select 1 
	from sys.tables as tbl
		inner join sys.schemas as sch on sch.schema_id = tbl.schema_id
	where tbl.name = 'gene'
	  and sch.name = 'stage'
)
create table stage.gene
(
	ensembl_id nvarchar(32),
	gene_symbol nvarchar(32),
	chromosome tinyint,
	start_pos int,
	end_pos int,
	gene_biotype nvarchar(32)
);
go

-- stage.gwas  
--   Landing table for GWAS datasets. 
--   NEED TO CONSIDER THIS ONE WHEN I COME TO LOAD GWAS DATA
--create table stage.gwas
--(
--);
--go

/*
 * Section 2: Dimension Tables
 *     dim_coordinate, dim_gene, dim_tissue, dim_trait, dim_population, dim_dataset
*/

-- dim_coordinate
--   contains genomic coordinates {CHR, START, END, CENTER} 
--   all positions map to human reference genome build 37
--   this table will be one of the largest tables
if exists (
	select 1 
	from sys.tables as tbl
		inner join sys.schemas as sch on sch.schema_id = tbl.schema_id
	where tbl.name = 'dim_coordinate'
	  and sch.name = 'dbo'
) drop table dbo.dim_coordinate;
create table dbo.dim_coordinate
(
    coord bigint primary key identity(1, 1),
	chromosome tinyint not null,
	start_pos int not null,
	end_pos int not null,
	center_pos int,
	index idx_coord_chr clustered (chromosome) with (fillfactor = 95, pad_index = on),
	constraint uniq_coord unique (chromosome, start_pos, end_pos)
);
-- WITH ( data_compression=page );
go

-- dim_gene
--   contains information relevant to genes.
--   initially, this table is a direct import from GTEx Gene Expression data
--   though it could be added to over time.

-- NEED TO THINK ABOUT INDEXES
if exists (
	select 1 
	from sys.tables as tbl
		inner join sys.schemas as sch on sch.schema_id = tbl.schema_id
	where tbl.name = 'dim_gene'
	  and sch.name = 'dbo'
) drop table dbo.dim_gene;
create table dbo.dim_gene
(
	gene_id int primary key identity(1, 1),
	coord bigint foreign key references dim_coordinate (coord),
	ensembl_id nvarchar(32),
	gene_symbol nvarchar(32) not null,
	gene_biotype nvarchar(32)
);
go

if exists (
	select 1 
	from sys.tables as tbl
		inner join sys.schemas as sch on sch.schema_id = tbl.schema_id
	where tbl.name = 'dim_tissue'
	  and sch.name = 'dbo'
) drop table dbo.dim_tissue;
create table dbo.dim_tissue
(
	tissue_id int primary key identity(1, 1),
	smts nvarchar(128),
	smtsd nvarchar(128)
);
go

-- Do I really need these tables? 
-- It would save space in the fact table, but then perhaps page compression will do the trick.
-- The only possible use I can think of, is if we want an interface to extract all unique traits / populations
-- in which case, these tables will provide a far quicker route.
if exists (
	select 1 
	from sys.tables as tbl
		inner join sys.schemas as sch on sch.schema_id = tbl.schema_id
	where tbl.name = 'dim_trait'
	  and sch.name = 'dbo'
) drop table dbo.dim_trait;
create table dbo.dim_trait
(
	trait_id int primary key identity(1, 1),
	trait nvarchar(32) not null,    -- e.g. BMI
);
go

if exists (
	select 1 
	from sys.tables as tbl
		inner join sys.schemas as sch on sch.schema_id = tbl.schema_id
	where tbl.name = 'dim_population'
	  and sch.name = 'dbo'
) drop table dbo.dim_population;
create table dbo.dim_population
(
	pop_id int primary key identity(1, 1),
	pop nvarchar(32) not null
);
go

if exists (
	select 1 
	from sys.tables as tbl
		inner join sys.schemas as sch on sch.schema_id = tbl.schema_id
	where tbl.name = 'dim_dataset'
	  and sch.name = 'dbo'
) drop table dbo.dim_dataset;
create table dbo.dim_dataset
(
	dataset_id int primary key identity(1, 1),
	dataset_name nvarchar(32) not null,
	dataset_description nvarchar(256)
);
go


/*
 * Section 3: Fact Tables
 *     fact_gwas, fact_qtl, fact_expression
*/
if exists (
	select 1 
	from sys.tables as tbl
		inner join sys.schemas as sch on sch.schema_id = tbl.schema_id
	where tbl.name = 'fact_gwas'
	  and sch.name = 'dbo'
) drop table dbo.fact_gwas;
create table dbo.fact_gwas
(
	coord bigint foreign key references dbo.dim_coordinate (coord),
	trait int foreign key references dbo.dim_trait (trait_id),
	pop int foreign key references dbo.dim_population (pop_id),
	dataset int foreign key references dbo.dim_dataset (dataset_id),
	A1 nvarchar(max),
	A2 nvarchar(max),
	beta float,
	pvalue float,
	n_samples int,
	allele_freq int
);
-- WITH ( data_compression = PAGE )
;
go


-- NEED TO THINK ABOUT INDEXES
if exists (
	select 1 
	from sys.tables as tbl
		inner join sys.schemas as sch on sch.schema_id = tbl.schema_id
	where tbl.name = 'fact_qtl'
	  and sch.name = 'dbo'
) drop table dbo.fact_qtl;
create table dbo.fact_qtl
(
	coord bigint foreign key references dbo.dim_coordinate (coord),
	gene int foreign key references dbo.dim_gene (gene_id),
	tissue int foreign key references dbo.dim_tissue (tissue_id),
	dataset int foreign key references dbo.dim_dataset (dataset_id),
	A1 nvarchar(max),
	A2 nvarchar(max),
	beta float,
	pvalue float--,
	--index idx_qtl_gene clustered (gene, tissue) with (fillfactor = 95, pad_index = ON)
);
-- WITH ( data_compression = PAGE );
go
-- note removed clustered index as it slowed down bulk inserts
-- this means I will have to pay A LOT of attention to appropriate indexing for queries.

if exists (
	select 1 
	from sys.tables as tbl
		inner join sys.schemas as sch on sch.schema_id = tbl.schema_id
	where tbl.name = 'fact_expression'
	  and sch.name = 'dbo'
) drop table dbo.fact_expression;
create table dbo.fact_expression
(
	gene int foreign key references dbo.dim_gene (gene_id),
	tissue int foreign key references dbo.dim_tissue (tissue_id),
	dataset int foreign key references dbo.dim_dataset (dataset_id),
	rpkm float
	index idx_expr_gene clustered (gene, tissue) with (fillfactor = 95, pad_index = ON)
);
-- WITH ( data_compression = PAGE );
go






