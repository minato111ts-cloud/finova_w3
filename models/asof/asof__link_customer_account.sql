select * from {{ ref('link_customer_account') }}
where ingested_ts <= current_setting('finova.asof_cutoff')::timestamptz
