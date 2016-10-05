/*
 * ETL DIAGRAM T2D GWAS results
 *
 * bulk loaded into stage.gwas via SQL Server Data Import / Export
 * unstage into fact_gwas:
 *     dataset_id = 2
 *     trait (diabetes) = 3
 *     population (EUR / Mixed) = 5
 *
 * Nick Burns
 * 5 Oct, 2016
*/

select top 5* from stage.gwas
-- STEP 1:
-- Determine how well the {CHR, start} columns map to dim_snp
select count(*) from stage.gwas    
-- 2914608 rows (note that ~1000 positions did not lift over from hg18 to hg19)

select G.SNP, S.chromosome, S.position, S.rsid
from stage.gwas G
  inner join dim_snp S on (
	S.chromosome = G.CHR
	and S.position = G.start
	and G.RISK_ALLELE = S.A1
	and G.OTHER_ALLELE = S.A2
) -- 1,379,844 rows - so not great matching (~ 50 %)
select G.SNP, S.chromosome, S.position, S.rsid
from stage.gwas G
  inner join dim_snp S on (
	S.chromosome = G.CHR
	and S.position = G.start
	and G.RISK_ALLELE = S.A2
	and G.OTHER_ALLELE = S.A1
)  -- 1,414,957 rows
-- so combined we have ~95 % of the data matching

-- UNSTAGE
-- Here we go then, going with the two queries above, let's unstage the data
select top 5 * from fact_gwas
select top 5 * from stage.gwas


begin tran


insert into fact_gwas (snp_id, trait, pop, dataset, beta, se, pvalue, n_samples, allele_freq)
select 
	S.snp_id, 
	3 as 'trait', 5 as 'pop', 2 as 'dataset',
	G.[OR] as 'beta', 
	abs(G.[OR] - G.[OR_95L]) / 1.96 as 'se',
	G.[P] as 'pvalue',
	G.[N] as 'n_samples',
	NULL as 'allele_freq'
from stage.gwas G
	inner join dim_snp S on (
	S.chromosome = G.CHR
	and S.position = G.start
	and G.RISK_ALLELE = S.A1
	and G.OTHER_ALLELE = S.A2
) 
union all
select 
	S.snp_id, 
	3 as 'trait', 5 as 'pop', 2 as 'dataset',
	G.[OR] as 'beta', 
	abs(G.[OR] - G.[OR_95L]) / 1.96 as 'se',
	G.[P] as 'pvalue',
	G.[N] as 'n_samples',
	NULL as 'allele_freq'
from stage.gwas G
  inner join dim_snp S on (
	S.chromosome = G.CHR
	and S.position = G.start
	and G.RISK_ALLELE = S.A2
	and G.OTHER_ALLELE = S.A1
)
-- 2794801 rows inserted

--  commit		rollback

-- CLEANUP
truncate table stage.gwas;
drop table stage.gwas;
