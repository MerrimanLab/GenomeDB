/* 
 * GenomeDW Indexes
 * Indexes for querying GenomeDB. These should be tested and run manually as required.
 *
 *
 * Created: 25 August, 2016
 * Edits:
 *   25 August, 2016: created by Nick Burns
 *
*/

use [GenomeDB];
go

drop index idx_tissue on dbo.fact_qtl;
go

create nonclustered index idx_qtl_gene on dbo.fact_qtl (gene, tissue);
go


create nonclustered index idx_snp_position on dim_snp (rsid) include (coord);
go


create nonclustered index idx_gwas_by_coordintate on fact_gwas (trait, coord, pvalue);
go