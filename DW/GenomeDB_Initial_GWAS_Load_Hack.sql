
select top 5 * from dim_dataset;

insert into dim_dataset (dataset_name, dataset_description)
select 'Kottgen', 'Kottgen et al (2013) GWAS results';
go

select top 5 * from dim_trait;
insert into dim_trait (trait) select 'gout';
go

select top 5 * from dim_population;
insert into dim_population select 'EUR';

select substring('chr10', 4, len('chr10'))
select len('chr10')
select top 5 * from stage.kottgen_urate;
select top 5 * from dim_coordinate;

begin tran
update stage.kottgen_urate set chromosome = substring(chromosome, 4, len(chromosome));

-- commit    rollback


select top 10 * from stage.kottgen_gout K 
	inner join dim_coordinate C on C.chromosome = K.chromosome and C.start_pos = K.hg19_position and C.end_pos = K.hg19_position
select count(*) from stage.diagram_t2d;
select count(*) from stage.diagram_t2d D inner join dim_coordinate C on C.chromosome = D.CHR and C.start_pos = D.POS and C.end_pos = D.POS

select distinct chromosome from stage.kottgen_urate;
begin tran
delete from stage.kottgen_urate
where chromosome in ('1_gl0', 'L', 'X', 'Y', 'Un_gl')

begin tran
insert into dim_coordinate (chromosome, start_pos, end_pos, center_pos)
select distinct K.chromosome, hg19_position, hg19_position, hg19_position
from stage.kottgen_urate K
left join dim_coordinate C on C.chromosome = K.chromosome and C.start_pos = K.hg19_position and C.end_pos = K.hg19_position
where C.coord is NULL

--   commit    rollback



select top 5 * from dim_snp;
select top 5 * from stage.kottgen_urate;

begin tran
insert into dim_snp (coord, rsid)
select distinct C.coord, K.markername
from stage.kottgen_urate K
	inner join dim_coordinate C on C.chromosome = K.chromosome and C.start_pos = K.hg19_position and C.end_pos = K.hg19_position
	left join dim_snp S on S.rsid = K.markername
where S.rsid is null;

--   commit    rollback


select top 5 * from stage.kottgen_urate;
select top 5 * from fact_gwas;
select count(*) from fact_gwas;


begin tran
insert into fact_gwas (coord, trait, pop, dataset, A1, A2, beta, pvalue, n_samples_controls)
select S.coord, 4, 2, 5, A1, A2, beta, p_gc, n_total 
from stage.kottgen_urate K
	inner join dim_snp S on S.rsid = K.markername

-- commit    rollback
	

drop table stage.kottgen_urate;