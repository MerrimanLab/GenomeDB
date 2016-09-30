/* 
 * GenomeDW ETL snippets
 * Code snippets and stored procedure definitions for ETL processes
 *
 *
 * Created: 21 September, 2016
 * Edits:
 *    
 *
*/
USE [GenomeDB]
go

if not exists (select 1 from INFORMATION_SCHEMA.SCHEMATA where schema_name = 'etl')
	exec sp_executesql N'create schema etl';
go


create procedure [etl].[reset_staging]
as
  begin
    truncate table [GenomeDB].[stage].[qtl];
	truncate table [GenomeDB].[stage].[expression];
	--drop index idx_stage_qtls on [stage].[qtl];
  end
go


create procedure [etl].[manage_index_fact_expression] (
	@state int
)
as
  begin
	if (@state = 0) 
	begin
		-- drop clustered index prior to loading data
		drop index idx_expr_gene on fact_expression;
	end
	else
	begin
		-- recreate clustered index post data load
		create clustered index idx_expr_gene on fact_expression (gene asc, tissue asc);
	end
  end
go


/*
 * This is the sproc that I ended up using.
 * Trialled indexing and not indexing the joins, found that a table scan (stage.qtl)
 * occurred regardless, so choose not to index.
 * Joins are pretty cost-effective, it is the write to disk that takes the time.
*/
create procedure etl.sproc_unstage_qtls
as
begin
	--create index idx_etl_qtl_gene_tissue_map on stage.qtl (ensembl_id, tissue_name);
	--create index idx_etl_qtl_snp_map on stage.qtl ( chromosome asc, position asc, A1 asc, A2 asc);
	
	 insert into fact_qtl
	 select * from (
		  select G.gene_id, T.tissue_id, 1 as dataset_id, S.snp_id, beta, pvalue
			from stage.qtl Q
			  inner join dim_gene G on G.ensembl_id = Q.ensembl_id
			  inner join dim_tissue T on T.smtsd = Q.tissue_name
			  inner join dim_snp S on (S.chromosome = Q.chromosome
				   and S.position = Q.position
				   and S.A1 = Q.A1 and S.A2 = Q.A2)
		  union all
		  select G.gene_id, T.tissue_id, 1 as dataset_id, S.snp_id, beta, pvalue
			from stage.qtl Q
			  inner join dim_gene G on G.ensembl_id = Q.ensembl_id
			  inner join dim_tissue T on T.smtsd = Q.tissue_name
			  inner join dim_snp S on (S.chromosome = Q.chromosome
				   and S.position = Q.position
				   and S.A1 = Q.A2 and S.A2 = Q.A1)
	 ) as T;
end
go

create procedure [etl].[sproc_unstage_expression]
as
begin
	with tissue_map as
	(
		select t1.tissue_id, m.sample_id
		from stage.meta m
		  inner join dim_tissue t1 on t1.smtsd = m.smtsd
	)
	insert into [dbo].[fact_expression]
	select G.gene_id, T.tissue_id, 1, S.rpkm
	from [stage].[expression] S
	  inner join dim_gene G on G.ensembl_id = S.ensembl_id  
	  inner join tissue_map T on T.sample_id = S.sample_id;
end;