-- Grain: 1 dòng = 1 giao dịch tiền (fact giao dịch)
-- Chiều tiền lấy từ seed txn_type (cấu hình), không ghi cứng trong SQL
with t as (
    select * from {{ ref('stg_luyen_tap__cash_txn') }}
),
a as (
    select * from {{ ref('dim_account') }} where account_id <> '<UNKNOWN>'
),
b as (
    select * from {{ ref('dim_branch') }} where branch_code <> '<UNKNOWN>'
)
select
    t.txn_id,
    {{ date_key('t.txn_date') }}                       as date_key,
    t.txn_ts,
    coalesce(a.account_key, {{ unknown_key() }})       as account_key,
    coalesce(b.branch_key,  {{ unknown_key() }})       as branch_key,
    a.customer_id,
    t.account_id                                       as source_account_id,   -- giữ để truy vết dòng mồ côi
    t.txn_type,
    tt.txn_group,
    tt.direction,
    t.amount,
    (tt.direction * t.amount)::numeric(20,2)           as signed_amount,
    t.ref_order_id
from t
left join {{ ref('txn_type') }} tt on tt.txn_type = t.txn_type
left join a on a.account_id = t.account_id
left join b on b.branch_code = a.branch_code
