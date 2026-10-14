-- Staging chỉ làm luật cứng: chuẩn hóa khóa, loại dòng trùng hoàn toàn, tính khóa băm và hash_diff.
-- Không phân loại, không suy luận (ADR-016 Q19).
with src as (
    select distinct
        upper(trim(customer_id))   as customer_id,
        upper(trim(segment))       as segment,
        upper(trim(kyc_status))    as kyc_status,
        updated_at
    from {{ source('luyen_tap', 'customers') }}
)
select
    customer_id, segment, kyc_status, updated_at,
    {{ dv_hk(['customer_id']) }}                        as customer_hk,
    {{ hash_key(['segment', 'kyc_status']) }}          as sat_customer__luyen_tap_hd,
    {{ replay_ingested_ts('updated_at') }}             as ingested_ts,
    (updated_at::timestamp at time zone '{{ var("tz") }}') as event_ts,
    'luyen_tap.customers'::text                        as record_source
from src
