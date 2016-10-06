/*
 * ETL GIANT Locke BMI / Obesity GWAS results
 *
 * bulk loaded into stage.gwas via SQL Server Data Import / Export
 * unstage into fact_gwas:
 *     dataset_id = 3 (GIANT)
 *     trait (diabetes) = 1 (BMI)
 *     population (EUR / Mixed) = 5
 *
 * Nick Burns
 * 6 Oct, 2016
*/

-- STEP 1: A quick look...
select top 5* from stage.gwas
select count(*) from stage.gwas    
-- 2500573 rows

-- There are no positions, so we have to map on {RSID, A1, A2}. 
-- GIANT's documentation sggests that the RSIDs are consistent with dbSNP, build37
-- so hopefully we can get a direct mapping by RSID.
select S.rsid, S.chromosome, S.position, G.*
from stage.gwas G
  inner join dim_snp S on S.rsid = G.SNP;
-- 2499206 rows, 99.9 % of the data. This is really good

-- Let's see if we are missing out on anything interesting which doesn't map across.
select S.rsid, S.chromosome, S.position, G.*
from stage.gwas G
  left join dim_snp S on S.rsid = G.SNP
where S.rsid is null
order by G.p asc;
-- there is only one SNP here that exceeds genome-wide sig
-- given that signals are generally clusters of SNPs, we aren't losing any information
-- by excluding those that dont map.


-- STEP 2:
-- UNSTAGE
/*
 *     dataset_id = 3 (GIANT)
 *     trait (diabetes) = 1 (BMI)
 *     population (EUR / Mixed) = 5
*/
begin tran

insert into fact_gwas (snp_id, trait, pop, dataset, beta, se, pvalue, n_samples, allele_freq)
select 
	S.snp_id, 
	1 as 'trait', 5 as 'pop', 3 as 'dataset',
	G.[b] as 'beta', 
	G.[se] as 'se',
	G.[p] as 'pvalue',
	G.[N] as 'n_samples',
	G.[Freq1 Hapmap] as 'allele_freq'
from stage.gwas G
	inner join dim_snp S on S.rsid = G.SNP
-- 2499206 rows inserted

--  commit		rollback

-- CLEANUP
truncate table stage.gwas;
drop table stage.gwas;
