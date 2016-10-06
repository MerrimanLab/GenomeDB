/*
 * ETL Kottgen Urate GWAS results
 *
 * bulk loaded into stage.gwas via SQL Server Data Import / Export
 * unstage into fact_gwas:
 *     dataset_id = 4 (Kottgen)
 *     trait (Urate) = 7
 *     population (EUR) = 4
 *
 *
 * Nick Burns
 * 6 Oct, 2016
*/


-- STEP 1: A quick look...
select top 5* from stage.gwas
select count(*) from stage.gwas    
-- 2450547 rows

-- Let's see how well the RSIDs map:
select S.rsid, S.chromosome, S.position, S.A1, S.A2, G.*
from stage.gwas G
  inner join dim_snp S on S.rsid = G.MarkerName;
-- 2447444 rows, 99.8 % of the data.
-- happy with this

-- Also looked at RSIDs that did not match:
--    one SNP had a pvalu ~ 10-31
--    5 more had pvalues ~ 10-05
-- If this signal is real, then there should be plenty more around them

-- Also confirmed that there are some cases where RSIDs match, but alleles are flipped. Happy with this not being an issue.


-- STEP 2:
-- UNSTAGE
/*
 *     dataset_id = 4 (Kottgen)
 *     trait (Urate) = 7
 *     population (EUR) = 4
*/
begin tran

insert into fact_gwas (snp_id, trait, pop, dataset, beta, se, pvalue, n_samples, allele_freq)
select 
	S.snp_id, 
	7 as 'trait', 4 as 'pop', 4 as 'dataset',
	G.[beta] as 'beta', 
	G.[se] as 'se',
	G.[p_gc] as 'pvalue',
	G.[n_total] as 'n_samples',
	NULL as 'allele_freq'
from stage.gwas G
	inner join dim_snp S on S.rsid = G.MarkerName;
-- 2447444 rows inserted  (expecting: 2447444 rows)

--  commit		rollback

-- CLEANUP
truncate table stage.gwas;
drop table stage.gwas;
