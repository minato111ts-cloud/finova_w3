select * from {{ ref('link_customer_account') }}
where ingested_ts <= {{ get_asof_cutoff() }}

