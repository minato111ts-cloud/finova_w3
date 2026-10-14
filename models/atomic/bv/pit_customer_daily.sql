-- Grain: 1 dòng = 1 khách × 1 ngày D. Con trỏ tới phiên bản satellite hiệu lực tại D (mẫu T-BV)
-- Dựng lại ngày D: delete+insert theo as_of_date, nên chạy lại cùng D cho cùng kết quả
{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='as_of_date',
    pre_hook="{{ asof_set_session() }}"
) }}
select
    h.customer_hk,
    current_setting('finova.asof_date')::date            as as_of_date,
    current_setting('finova.asof_cutoff')::timestamptz   as cutoff_ts,
    s.ingested_ts                                        as sat_customer__luyen_tap_ingested_ts
from {{ ref('asof__hub_customer') }} h
left join {{ ref('asof__sat_customer__luyen_tap') }} s on s.customer_hk = h.customer_hk
