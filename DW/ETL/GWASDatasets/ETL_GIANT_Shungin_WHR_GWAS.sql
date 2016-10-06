/*
 * ETL GIANT Shungin WHR GWAS results
 *
 * bulk loaded into stage.gwas via SQL Server Data Import / Export
 * unstage into fact_gwas:
 *     dataset_id = 3 (GIANT)
 *     trait (WHR) = 8
 *     population (EUR / Mixed) = 5
 *
 * Pre-filtering of data
 * ---------------------
 *
 * The GWAS summary file was prefiltered as follows:
 *     1. Where FreqA1HapMapCEU == NA <- 0
 *     2. Removed 294 rows where CHR and POS were NA. 
 *        One of these was genome-wide significant (~10-11), bu only one. No information lost therefore.
 *
 * Nick Burns
 * 6 Oct, 2016
*/


-- STEP 1: A quick look...
select top 5* from stage.gwas
select count(*) from stage.gwas    
-- 2562422 rows

-- GIANT's documentation suggests that RSIDs are consistent with dbSNP build37
-- so I am hoping that we can merge on these, rather than having to go to {CHR, POS, Alleles}
-- Let's see how well the RSIDs map:
select S.rsid, S.chromosome, S.position, G.*
from stage.gwas G
  inner join dim_snp S on S.rsid = G.MarkerName;
-- 2529489 rows, 98.7 % of the data.

/*
 * There is really good mapping on the rsids, but, the positions are way out!
 * I need to look at these again, and confirm the alleles
 *
*/
select S.chromosome, S.position, G.POS, S.A1, G.A1, S.A2, G.A2
from stage.gwas G
  inner join dim_snp S on S.rsid = G.MarkerName
where S.A1 != G.A1;

/* 
 * Good news, where alleles do not match, they are simply flipped
 * In terms of positions, I am going to trust the dbSNP (dim_snp) positions
 * It feels like the GIANT dataset might not be totally up-to-date. 
 * Perhaps it is actually hg18, but since we have good RSID mapping, will be very happy with this.
 *
*/


-- STEP 2:
-- UNSTAGE
/*
 *     dataset_id = 3 (GIANT)
 *     trait (WHR) = 8
 *     population (EUR / Mixed) = 5
*/
begin tran

insert into fact_gwas (snp_id, trait, pop, dataset, beta, se, pvalue, n_samples, allele_freq)
select 
	S.snp_id, 
	8 as 'trait', 5 as 'pop', 3 as 'dataset',
	G.[b] as 'beta', 
	G.[se] as 'se',
	G.[p] as 'pvalue',
	G.[N] as 'n_samples',
	G.[FreqA1HapMapCEU] as 'allele_freq'
from stage.gwas G
	inner join dim_snp S on S.rsid = G.MarkerName
-- ... rows inserted  (expecting: 2529489 rows)

--  commit		rollback

-- CLEANUP
truncate table stage.gwas;
drop table stage.gwas;
