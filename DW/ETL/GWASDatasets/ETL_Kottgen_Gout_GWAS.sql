/*
 * ETL Kottgen Gout GWAS results
 *
 * bulk loaded into stage.gwas via SQL Server Data Import / Export
 * unstage into fact_gwas:
 *     dataset_id = 4 (Kottgen)
 *     trait (Gout) = 5
 *     population (EUR) = 4
 *
 *
 * Nick Burns
 * 6 Oct, 2016
*/


-- STEP 1: A quick look...
select top 5* from stage.gwas
select count(*) from stage.gwas    
-- 2538056 rows

-- Let's see how well the RSIDs map:
select S.rsid, S.chromosome, S.position, S.A1, S.A2, G.*
from stage.gwas G
  inner join dim_snp S on S.rsid = G.MarkerName;
-- 2534515 rows, 99.8 % of the data.
-- happy with this


-- STEP 2:
-- UNSTAGE
/*
 *     dataset_id = 4 (Kottgen)
 *     trait (Gout) = 5
 *     population (EUR) = 4
*/
begin tran

insert into fact_gwas (snp_id, trait, pop, dataset, beta, se, pvalue, n_samples, allele_freq)
select 
	S.snp_id, 
	5 as 'trait', 4 as 'pop', 4 as 'dataset',
	G.[beta] as 'beta', 
	G.[se] as 'se',
	G.[p_gc] as 'pvalue',
	G.[n_total] as 'n_samples',
	NULL as 'allele_freq'
from stage.gwas G
	inner join dim_snp S on S.rsid = G.MarkerName;
-- 2534515 rows inserted  (expecting: 2534515 rows)

--  commit		rollback

-- CLEANUP
truncate table stage.gwas;
drop table stage.gwas;
