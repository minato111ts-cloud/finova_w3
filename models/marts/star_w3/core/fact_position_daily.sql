-- Grain: 1 dòng = 1 tài khoản × 1 mã × 1 ngày chụp (fact chụp định kỳ, thưa: chỉ khi total_qty > 0)
-- total_qty, market_value là đại lượng cộng được theo tài khoản và mã, KHÔNG cộng theo ngày
with p as (
    select * from {{ ref('stg_luyen_tap__position_daily') }}
),
a as (
    select * from {{ ref('dim_account') }} where account_id <> '<UNKNOWN>'
),
i as (
    select * from {{ ref('dim_instrument') }} where symbol <> '<UNKNOWN>'
),
b as (
    select * from {{ ref('dim_branch') }} where branch_code <> '<UNKNOWN>'
)
select
    {{ date_key('p.snapshot_date') }}                   as date_key,
    p.snapshot_date,
    coalesce(a.account_key,    {{ unknown_key() }})     as account_key,
    coalesce(i.instrument_key, {{ unknown_key() }})     as instrument_key,
    coalesce(b.branch_key,     {{ unknown_key() }})     as branch_key,
    p.account_id,
    a.customer_id,
    p.symbol,
    p.total_qty,
    p.receiving_qty,
    p.total_qty - p.receiving_qty                       as available_qty,
    p.close_price,
    (p.total_qty * p.close_price)::numeric(20,2)        as market_value
from p
left join a on a.account_id = p.account_id
left join i on i.symbol = p.symbol
left join b on b.branch_code = a.branch_code
