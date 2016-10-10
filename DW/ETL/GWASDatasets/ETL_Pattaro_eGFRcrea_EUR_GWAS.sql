/*
 * ETL Pattaro eGFRcrea EUR GWAS results
 *
 * bulk loaded into stage.gwas via SQL Server Data Import / Export
 * unstage into fact_gwas:
 *     dataset_id = 6 (Pattaro, CKDGen)
 *     trait (eGFRcrea) = 4
 *     population (EUR) = 4
 *
 *
 * Nick Burns
 * 7 Oct, 2016
*/


-- STEP 1: A quick look...
select top 5* from stage.gwas
select count(*) from stage.gwas    
-- 2198214 rows

-- No {CHR, POS} map on RSIDs
select S.rsid, S.chromosome, S.position, S.A1, S.A2, G.rsID, G.allele1, G.allele2, G.pval
from stage.gwas G
  inner join dim_snp S on S.rsid = G.rsID;
-- 2195764 rows, 99.9 % of the data.
-- happy with this
-- besides which, there is not much I can do without chr and positions :)


-- STEP 2:
-- UNSTAGE those that match
/*
 *     dataset_id = 6 (Pattaro, CKDGen)
 *     trait (eGFRcrea) = 4
 *     population (EUR) = 4
*/
begin tran

insert into fact_gwas (snp_id, trait, pop, dataset, beta, se, pvalue, n_samples, allele_freq)
select 
	S.snp_id, 
	4 as 'trait', 4 as 'pop', 6 as 'dataset',
	G.[beta] as 'beta', 
	G.[SE] as 'se',
	G.[pval] as 'pvalue',
	G.N as 'n_samples',
	G.[freqA1] as 'allele_freq'
from stage.gwas G
	inner join dim_snp S on S.rsid = G.rsid;
--  2195764 rows inserted  (expecting: 2195764 rows)

--  commit		rollback

-- CLEANUP
truncate table stage.gwas;
drop table stage.gwas;

