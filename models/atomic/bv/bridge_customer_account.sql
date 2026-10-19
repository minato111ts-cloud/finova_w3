-- Grain: 1 dòng = 1 tài khoản × 1 ngày D, kèm khách sở hữu. Làm phẳng đường khách → tài khoản (mẫu T-BRIDGE)
{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='as_of_date',
    pre_hook="{{ asof_set_session() }}"
) }}
{{ dv_bridge(
    grain_hk='account_hk',
    hk_cols=['customer_hk', 'link_customer_account_hk'],
    source='asof__link_customer_account'
) }}
