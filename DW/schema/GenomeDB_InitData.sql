/* 
 * GenomeDW Data Initialisation Script
 * Staging tables have been populated with initial datasets including:
 *   - GTEx expression data, GTEx gene information, GTEx metadata (tissue information)
 * This script will unstage the staging area to populate:
 *   - dim_datasets, dim_tissue, dim_coordinate, dim_gene, dim_expression
 *
 * Created: 8 August, 2016
 * Edits:
 *    
 *
*/
USE [GenomeDB]
go

-- dim_dataset
-- Create entry for GTEx
insert into dim_dataset (dataset_name, dataset_description)
select 'GTEx', 'GTEx public release, v4';
go

-- dim_tissue
-- Unstage stage.meta
begin tran
delete from dim_tissue;

insert into dim_tissue (smts, smtsd)
select distinct smts, smtsd from stage.meta
where smts is not null;
go

--   commit    rollback

-- dim_coordinate
-- populate dim_coordinate from stage.gene
begin tran
insert into dim_coordinate (chromosome, start_pos, end_pos, center_pos)
select distinct chromosome, start_pos, end_pos, floor((start_pos + end_pos) / 2 + 0.5)
from stage.gene;

--    commit    rollback

-- dim_gene
-- populate dim_gene from stage.gene
begin tran
insert into dim_gene (coord, ensembl_id, gene_symbol, gene_biotype)
select C.coord, S.ensembl_id, S.gene_symbol, S.gene_biotype
from stage.gene as S
  inner join dim_coordinate as C on (
	C.chromosome = S.chromosome and
	C.start_pos = S.start_pos and
	C.end_pos = S.end_pos
);
--    commit    rollback

-- dim_expression
-- unstage stage.expression into fact_expression
