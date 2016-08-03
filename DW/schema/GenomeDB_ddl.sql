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
 *
*/
USE [GenomeDB]
go
-- NOTE: created via the GUI. 4 data files, 1 log file, set to simple recovery

/*
 * Section 1: Staging Area
 *     TBC
*/


/*
 * Section 2: Dimension Tables
 *     dim_coordinate, dim_gene, dim_tissue, dim_trait, dim_population, dim_dataset
*/

-- dim_coordinate
--   contains genomic coordinates {CHR, START, END, CENTER} 
--   all positions map to human reference genome build 37
--   this table will be one of the largest tables
create table dbo.dim_coordinate
(
    coord bigint primary key identity(1, 1),
	chromosome tinyint not null,
	start_pos int not null,
	end_pos int not null,
	center_pos int,
	index idx_coord_chr clustered (chromosome) with (fillfactor = 95, pad_index = on),
	constraint uniq_coord unique (chromosome, start_pos, end_pos)
) WITH ( data_compression=page );
go

-- dim_gene
--   contains information relevant to genes.
--   initially, this table is a direct import from GTEx Gene Expression data
--   though it could be added to over time.

-- NEED TO THINK ABOUT INDEXES
create table dbo.dim_gene
(
	gene_id int primary key identity(1, 1),
	coord bigint foreign key references dim_coordinate (coord),
	ensembl_id nvarchar(32),
	gene_symbol nvarchar(32) not null,
	gene_biotype nvarchar(32)
);
go

create table dbo.dim_tissue
(
	tissue_id tinyint primary key identity(1, 1),
	smts nvarchar(128),
	smtsd nvarchar(128)
);
go

create table dbo.dim_trait
(
	trait_id tinyint primary key identity(1, 1),
	trait nvarchar(32) not null,    -- e.g. BMI
);
go

create table dbo.dim_population
(
	pop_id tinyint primary key identity(1, 1),
	pop nvarchar(32) not null
);
go

create table dbo.dim_dataset
(
	dataset_id tinyint primary key identity(1, 1),
	dataset_name nvarchar(32) not null,
	dataset_description nvarchar(256)
);
go


/*
 * Section 3: Fact Tables
 *     fact_gwas, fact_qtl, fact_expression
*/



create table dbo.fact_gwas
(
	coord bigint foreign key references dbo.dim_coordinate (coord),
	trait tinyint foreign key references dbo.dim_trait (trait_id),
	pop tinyint foreign key references dbo.dim_population (pop_id),
	dataset tinyint foreign key references dbo.dim_dataset (dataset_id),
	A1 nvarchar(max),
	A2 nvarchar(max),
	beta float,
	pvalue float,
	n_samples int,
	allele_freq int
) WITH ( data_compression = PAGE )
;
go


-- NEED TO THINK ABOUT INDEXES
create table dbo.fact_qtl
(
	coord bigint foreign key references dbo.dim_coordinate (coord),
	gene int foreign key references dbo.dim_gene (gene_id),
	tissue tinyint foreign key references dbo.dim_tissue (tissue_id),
	dataset tinyint foreign key references dbo.dim_dataset (dataset_id),
	A1 nvarchar(max),
	A2 nvarchar(max),
	beta float,
	pvalue float,
	index idx_qtl_gene clustered (gene, tissue) with (fillfactor = 95, pad_index = ON)
);
go

create table dbo.fact_expression
(
	gene int foreign key references dbo.dim_gene (gene_id),
	tissue tinyint foreign key references dbo.dim_tissue (tissue_id),
	dataset tinyint foreign key references dbo.dim_dataset (dataset_id),
	rpkm float
	index idx_expr_gene clustered (gene, tissue) with (fillfactor = 95, pad_index = ON)
);
go






