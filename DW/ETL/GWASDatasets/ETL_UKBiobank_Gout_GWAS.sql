/*
 * ETL UKBiobank Gout GWAS results
 *
 * bulk loaded into stage.gwas via SQL Server Data Import / Export
 * unstage into fact_gwas:
 *     dataset_id = 7 (UKBiobank)
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
-- 8220149 rows

-- Let's see how well the RSIDs map:
select S.rsid, S.chromosome, S.position, S.A1, S.A2, G.SNP, G.A1_ALL, G.A2_ALL, G.[OR]
from stage.gwas G
  inner join dim_snp S on S.rsid = G.SNP;
-- 8163725 rows, 99.3 % of the data.
-- happy with this


-- Quick check of RSIDs which do not map:
select S.rsid, S.chromosome, S.position, S.A1, S.A2, G.SNP, G.A1_ALL, G.A2_ALL, G.[OR], G.[P]
from stage.gwas G
  left join dim_snp S on S.rsid = G.SNP
where S.rsid is null
order by G.[P] asc
-- There are 2 SNPs which reach genome-wide significance (~ 10-18, ~10-11)
-- There are anoth 28 SNP ~10-05.
-- Some of these clearly do not match because the do not have rsids. I am going to have to do more for these.
-- I am going to extract these SNPs into their own staging table and deal with them separately after 
-- unstaging the rest.
select G.* into [stage].[gwas_nonmatch]
from stage.gwas G
  left join dim_snp S on S.rsid = G.SNP
where S.rsid is null;
-- 56424 rows  


-- STEP 2:
-- UNSTAGE those that match
/*
 *     dataset_id = 7 (UKBiobank)
 *     trait (Gout) = 5
 *     population (EUR) = 4
*/
begin tran

insert into fact_gwas (snp_id, trait, pop, dataset, beta, se, pvalue, n_samples, allele_freq)
select 
	S.snp_id, 
	5 as 'trait', 4 as 'pop', 7 as 'dataset',
	G.[OR] as 'beta', 
	G.[SE] as 'se',
	G.[P] as 'pvalue',
	NULL as 'n_samples',
	G.[MAF] as 'allele_freq'
from stage.gwas G
	inner join dim_snp S on S.rsid = G.SNP;
-- 8163725 rows inserted  (expecting: 8163725 rows)

--  commit		rollback

-- CLEANUP
truncate table stage.gwas;
drop table stage.gwas;


-- STEP 3: deal with the non-matching SNPs
--   For these, we will need to match on {CHR, BP, alleles} just like we did to unstage the QTL data
--   I am actually going to steal the query code from etl.sproc_unstage_qtls and modify it
select top 10 * from stage.gwas_nonmatch;

-- here we match in both the FWD and REVERSE directionsbased on CHR, POS and alleles
select * from (
		  select S.snp_id, G.*
			from stage.gwas_nonmatch G
			  inner join dim_snp S on (S.chromosome = G.CHR
				   and S.position = G.BP
				   and S.A1 = G.A1_ALL and S.A2 = G.A2_ALL)
		  union all
		  select S.snp_id, G.*
			from stage.gwas_nonmatch G
			  inner join dim_snp S on (S.chromosome = G.CHR
				   and S.position = G.BP
				   and S.A2 = G.A1_ALL and S.A1 = G.A2_ALL)
	 ) as T;
-- 46184 new matches, including a whole bunch without RSIDs
-- This is a good result.
-- Let's unstage these:

/*
 *     dataset_id = 7 (UKBiobank)
 *     trait (Gout) = 5
 *     population (EUR) = 4
*/
begin tran

insert into fact_gwas (snp_id, trait, pop, dataset, beta, se, pvalue, n_samples, allele_freq)
select * from (
		  select 
			S.snp_id,
			5 as 'trait',
			4 as 'pop',
			7 as 'dataset',
			G.[OR] as 'beta',
			G.[SE] as 'se',
			G.[P] as 'pvalue',
			NULL as 'n_samples',
			G.[MAF] as 'allele_freq'
			from stage.gwas_nonmatch G
			  inner join dim_snp S on (S.chromosome = G.CHR
				   and S.position = G.BP
				   and S.A1 = G.A1_ALL and S.A2 = G.A2_ALL)
		  union all
		  select 
			S.snp_id,
			5 as 'trait',
			4 as 'pop',
			7 as 'dataset',
			G.[OR] as 'beta',
			G.[SE] as 'se',
			G.[P] as 'pvalue',
			NULL as 'n_samples',
			G.[MAF] as 'allele_freq'
			from stage.gwas_nonmatch G
			  inner join dim_snp S on (S.chromosome = G.CHR
				   and S.position = G.BP
				   and S.A2 = G.A1_ALL and S.A1 = G.A2_ALL)
	 ) as T;
-- 46184 rows inserted  (expecting: 46184 rows)

--  commit		rollback

-- CLEANUP
truncate table stage.gwas_nonmatch;
drop table stage.gwas_nonmatch;

