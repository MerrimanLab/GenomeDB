/* 
 * GenomeDB QTL BRowser Stored Procedures
 * Data warehouse for the storage of genome-wide summary datasets
 *
 * Stored Procedures which support data access from the QTL Browser.
 * Majority of data access logic encoded in stored procedures to make it easier to optimise.
 *
 * Created: 10 October, 2016
 * Nick Burns
 *
*/
USE [GenomeDB]
go

if exists (
	select 1 from sys.sysobjects
	where name = 'gwas_dataset_info'
	  and xtype = 'P'
) drop procedure [dbo].[gwas_dataset_info];
go
create procedure [dbo].[gwas_dataset_info] 
as
begin
	with gwas_data as (
		select distinct dataset, trait, pop 
		from fact_gwas
	)
	select distinct 
		T.trait, D.dataset_name, P.pop
	from gwas_data G
		inner join dim_trait T on T.trait_id = G.trait
		inner join dim_dataset D on D.dataset_id = G.dataset
		inner join dim_population P on P.pop_id = G.pop;
end;
go

dbo.gwas_dataset_info