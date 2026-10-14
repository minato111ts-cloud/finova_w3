-- Grain: 1 dòng = 1 lệnh (fact giao dịch). Mọi lệnh, mọi trạng thái.
-- customer_key là phiên bản khách hiệu lực tại ngày đặt lệnh; không có phiên bản thì gắn "không xác định",
-- còn customer_id (khóa bền) vẫn giữ để phân tích theo khách.
-- Quy ước đo: chỉ trạng thái FILLED được tính là khớp (dữ liệu nguồn không có khối lượng khớp của PARTIAL).
with o as (
    select * from {{ ref('stg_luyen_tap__orders') }}
),
a as (
    select * from {{ ref('dim_account') }} where account_id <> '<UNKNOWN>'
),
c as (
    select * from {{ ref('dim_customer') }} where customer_id <> '<UNKNOWN>'
),
i as (
    select * from {{ ref('dim_instrument') }} where symbol <> '<UNKNOWN>'
),
b as (
    select * from {{ ref('dim_branch') }} where branch_code <> '<UNKNOWN>'
)
select
    o.order_id,
    {{ date_key('o.trade_date') }}                                as date_key,
    o.order_ts,
    coalesce(a.account_key,    {{ unknown_key() }})               as account_key,
    coalesce(c.customer_key,   {{ unknown_key() }})               as customer_key,
    coalesce(b.branch_key,     {{ unknown_key() }})               as branch_key,
    coalesce(i.instrument_key, {{ unknown_key() }})               as instrument_key,
    a.customer_id,
    o.symbol,
    o.side,
    o.status,
    o.is_pre_session,
    o.status = 'FILLED'                                            as is_filled,
    o.quantity                                                     as order_qty,
    o.price                                                        as order_price,
    (o.quantity * o.price)::numeric(20,2)                          as order_value,
    case when o.status = 'FILLED' then o.quantity else 0 end       as filled_qty,
    case when o.status = 'FILLED' then (o.quantity * o.price)::numeric(20,2) else 0 end as filled_value,
    -- mua cộng, bán trừ
    case when o.status = 'FILLED'
         then (case o.side when 'B' then 1 else -1 end * o.quantity * o.price)::numeric(20,2)
         else 0 end                                                as net_filled_value
from o
left join a on a.account_id = o.account_id
left join c on c.customer_id = a.customer_id
           and o.trade_date >= c.valid_from
           and o.trade_date <  c.valid_to
left join i on i.symbol = o.symbol
left join b on b.branch_code = a.branch_code
