-- Grain: 1 dòng = 1 tài khoản × 1 ngày D, kèm khách sở hữu. Làm phẳng đường khách → tài khoản
{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='as_of_date',
    pre_hook="{{ asof_set_session() }}"
) }}
select
    current_setting('finova.asof_date')::date            as as_of_date,
    l.account_hk,
    l.customer_hk,
    l.link_customer_account_hk,
    current_setting('finova.asof_cutoff')::timestamptz   as cutoff_ts
from {{ ref('asof__link_customer_account') }} l
