/*
 * ETL GIANT Wood Height GWAS results
 *
 * bulk loaded into stage.gwas via SQL Server Data Import / Export
 * unstage into fact_gwas:
 *     dataset_id = 3 (GIANT)
 *     trait (Height) = 6
 *     population (EUR / Mixed) = 5
 *
 * Pre-filtering of data
 * ---------------------
 *
 * The GWAS summary file was prefiltered as follows:
 *     1. Where FreqA1HapMapCEU == NA <- 0
 *
 * Nick Burns
 * 6 Oct, 2016
*/


-- STEP 1: A quick look...
select top 5* from stage.gwas
select count(*) from stage.gwas    
-- 2680062 rows

-- GIANT's documentation suggests that RSIDs are consistent with dbSNP build37
-- Let's see how well the RSIDs map:
select S.rsid, S.chromosome, S.position, G.*
from stage.gwas G
  inner join dim_snp S on S.rsid = G.MarkerName;
-- 2675342 rows, 99.8 % of the data.

-- STEP 2:
-- UNSTAGE
/*
 *     dataset_id = 3 (GIANT)
 *     trait (Height) = 6
 *     population (EUR / Mixed) = 5
*/
begin tran

insert into fact_gwas (snp_id, trait, pop, dataset, beta, se, pvalue, n_samples, allele_freq)
select 
	S.snp_id, 
	6 as 'trait', 5 as 'pop', 3 as 'dataset',
	G.[b] as 'beta', 
	G.[SE] as 'se',
	G.[p] as 'pvalue',
	G.[N] as 'n_samples',
	G.[Freq Allele1 HapMapCEU] as 'allele_freq'
from stage.gwas G
	inner join dim_snp S on S.rsid = G.MarkerName;
-- 2675342 rows inserted  (expecting: 2675342 rows)

--  commit		rollback

-- CLEANUP
truncate table stage.gwas;
drop table stage.gwas;
