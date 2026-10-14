-- Grain: 1 dòng = 1 phiên bản khách theo thời điểm hệ thống biết, cộng 1 dòng "không xác định"
-- Dựng từ satellite, không từ staging: lịch sử đã nằm ở vault
with v as (
    select
        s.customer_hk, h.customer_id, s.segment, s.kyc_status, s.ingested_ts,
        lead(s.ingested_ts) over (partition by s.customer_hk order by s.ingested_ts) as next_ts,
        row_number()        over (partition by s.customer_hk order by s.ingested_ts) as version_no
    from {{ ref('sat_customer__luyen_tap') }} s
    join {{ ref('hub_customer') }} h on h.customer_hk = s.customer_hk
)
select
    {{ hash_key([fmt_hk('customer_hk'), fmt_ts('ingested_ts')]) }}     as customer_key,
    customer_hk,
    customer_id::text                                                  as customer_id,
    segment::text                                                      as segment,
    kyc_status::text                                                   as kyc_status,
    ingested_ts                                                        as valid_from_ts,
    coalesce(next_ts, 'infinity'::timestamptz)                         as valid_to_ts,
    next_ts is null                                                    as is_current,
    version_no::int                                                    as version_no
from v
union all
select {{ unknown_key() }}, null, '<UNKNOWN>', 'UNKNOWN', 'UNKNOWN', '-infinity', 'infinity', false, 0
