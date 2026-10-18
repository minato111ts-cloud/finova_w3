-- Grain: 1 dòng = 1 tài khoản × 1 ngày D, kèm khách sở hữu. Làm phẳng đường khách → tài khoản
{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='as_of_date',
    pre_hook="{{ asof_set_session() }}"
) }}
select
    {{ get_asof_date() }}   as as_of_date,
    l.account_hk,
    l.customer_hk,
    l.link_customer_account_hk,
    {{ get_asof_cutoff() }} as cutoff_ts
from {{ ref('asof__link_customer_account') }} l
where l.ingested_ts <= {{ get_asof_cutoff() }}

