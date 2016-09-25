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
 *    20 Sept, 2016: began working ov version2: dbSNP147 reference coordinate system
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
	A1 nvarchar(4000),
	A2 nvarchar(4000),
	genome_build char(3),
	beta float,
	tstat float,
	pvalue float,
	tissue_name nvarchar(128),
	dataset_id int null,
	gene_id int null,
	tissue_id int null,
	snp_id int null
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
--   These tables will be created as required. Data to be loaded manually via SQL Server Data Import / Export tool.

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
	where tbl.name = 'dim_snp'
	  and sch.name = 'dbo'
) drop table dbo.dim_snp;

-- EDITS:
--    RENAMED dim_coordinate -> dim_snp. This table now reserved for snps only!
--    removed center_pos, this is a simple calculation and doesn't need to be stored
--    added page compression (target server: SQL Server 2016 Enterprise)
--    dropped coord from bigint to int (won't exceed 2 billion, likely to be ~ 200 million rows)
--    ADDED:  A1, A2 and RSID. These are based on dbSNP Build 147 and form the reference coordinate system
--            for the rest of the data warehouse
--       Unique constraint added on (chromosome, start_pos, end_pos, rsid)
-- NOTES:
--    when loading data, will need to convert X and MT chromosome to integers (23, 24 repsectively)
--    use SQL Server Data Import / Export tool to stage dbSNP147 (~ 4GB, ~150 million rows)
create table dbo.dim_snp
(
    snp_id int primary key identity(1, 1),
	chromosome tinyint not null,
	position int not null,
	rsid nvarchar(64), 
	A1 nvarchar(4000),
	A2 nvarchar(4000),
	index idx_snp_chromosome clustered (chromosome)
) WITH ( data_compression=page );
go
-- create the following indexes after bulk load & prior to loading QTL / GWAS sets:
/*
create clustered index idx_coord_chr on dim_snp (chromosome);  
create nonclustered index idx_snp_mapping on dim_snp (chromosome)  
  include (position, A1, A2);
*/

-- dim_gene
--   contains information relevant to genes.
--   initially, this table is a direct import from GTEx Gene Expression data
-- EDITS
--    This no longer references dim_coordinate. dim_coordinate will be reserved for snps only.
--    NOTE: dim_coordinate now renamed to dim_snp.
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
	chromosome tinyint,
	gene_start int not null,
	gene_end int not null,
	ensembl_id nvarchar(32),
	gene_symbol nvarchar(32) not null,
	gene_biotype nvarchar(32)
);
go
-- try to build this as a clustered index after data loading
-- create nonclustered index idx_gene on dim_gene (gene_symbol, gene_id);

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

-- dim_trait
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

-- dim_population
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

-- dim_dataset
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

-- EDITS
--    removed A1 and A2, putting these into dim_coordinate (now dim_snp) in version2
--      this means that all coordinates are (chr, pos, a1, a2) as defined by dbSNP147
--    Excluding HWE info for now. Very few GWAS summary sets come with this information
--    Considered adding risk_allele, but few GWAS summary sets include this explicitly.
create table dbo.fact_gwas
(
	snp_id int foreign key references dbo.dim_snp (snp_id),
	trait int foreign key references dbo.dim_trait (trait_id),
	pop int foreign key references dbo.dim_population (pop_id),
	dataset int foreign key references dbo.dim_dataset (dataset_id),
	--A1 nvarchar(max),
	--A2 nvarchar(max),
	beta float,
	se float,
	pvalue float,
	n_samples int,
	allele_freq int
) WITH ( data_compression = PAGE )
;
go

if exists (
	select 1 
	from sys.tables as tbl
		inner join sys.schemas as sch on sch.schema_id = tbl.schema_id
	where tbl.name = 'fact_qtl'
	  and sch.name = 'dbo'
) drop table dbo.fact_qtl;

-- EDITS
--    included foreign key references to dim_coord on snp_position
--    removed A1 and A2, these are now defined as part of dim_coord
--    removed clustered index as it slowed down bulk inserts. Will attempt to build his post-data loading
create table dbo.fact_qtl
(
	gene int foreign key references dbo.dim_gene (gene_id),
	tissue int foreign key references dbo.dim_tissue (tissue_id),
	dataset int foreign key references dbo.dim_dataset (dataset_id),
	snp int foreign key references dbo.dim_snp (snp_id),
	--A1 nvarchar(max),
	--A2 nvarchar(max),
	beta float,
	pvalue float--,
	--index idx_qtl_gene clustered (gene, tissue) with (fillfactor = 95, pad_index = ON)
) WITH ( data_compression = PAGE );
go
-- try to buil clustered index post-data loading, else build the nonclustered index below
-- create nonclustered index idx_qtl_gene on dbo.fact_qtl (gene, tissue);

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
) WITH ( data_compression = PAGE );
go






