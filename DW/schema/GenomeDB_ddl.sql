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
