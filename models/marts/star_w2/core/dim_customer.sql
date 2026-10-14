-- Grain: 1 dòng = 1 phiên bản khách hàng (SCD2), cộng 1 dòng "không xác định"
-- Phiên bản mới chỉ sinh khi nội dung (segment, kyc_status) khác phiên bản liền trước:
-- A → B → A là 3 phiên bản; dòng nạp lại không đổi nội dung không sinh phiên bản.
-- valid_to là mốc loại trừ: phiên bản hiệu lực khi valid_from <= ngày < valid_to.
with v as (
    select
        customer_id, segment, kyc_status, updated_at,
        {{ hash_key(['segment', 'kyc_status']) }} as hash_diff
    from {{ ref('stg_luyen_tap__customers') }}
),
chg as (
    select *, lag(hash_diff) over (partition by customer_id order by updated_at) as prev_hash
    from v
),
kept as (
    select customer_id, segment, kyc_status, updated_at as valid_from
    from chg
    where prev_hash is null or prev_hash <> hash_diff
),
ver as (
    select
        *,
        lead(valid_from) over (partition by customer_id order by valid_from)       as next_from,
        row_number()     over (partition by customer_id order by valid_from)       as version_no
    from kept
)
select
    {{ hash_key(['customer_id', 'valid_from']) }}  as customer_key,
    customer_id,
    segment,
    kyc_status,
    valid_from,
    coalesce(next_from, date '9999-12-31')         as valid_to,
    next_from is null                              as is_current,
    version_no
from ver
union all
select {{ unknown_key() }}, '<UNKNOWN>', 'UNKNOWN', 'UNKNOWN', date '1900-01-01', date '9999-12-31', false, 0
