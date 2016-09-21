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
USE [GenomeDBv2]
go

if not exists (select 1 from INFORMATION_SCHEMA.SCHEMATA where schema_name = 'etl')
	exec sp_executesql N'create schema etl';
go


