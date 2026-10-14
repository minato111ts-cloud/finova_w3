-- Grain: 1 dòng = 1 tài khoản × 1 ngày giao dịch (bảng dày: đủ mọi tài khoản, mọi phiên, kể cả ngày không phát sinh)
-- Phạm vi ngày: các ngày có dữ liệu số dư chứng khoán (ngày chụp đầu kỳ tới phiên cuối)
-- cash_balance: tiền đã thanh toán tới hết ngày (giao dịch theo ngày giờ Việt Nam)
with bounds as (
    select min(snapshot_date) as d0, max(snapshot_date) as d1
    from {{ ref('fact_position_daily') }}
),
cal as (
    select d.date_key, d.date_day, d.is_trading_day, d.trading_day_number
    from {{ ref('dim_date') }} d, bounds
    where d.date_day between bounds.d0 and bounds.d1
),
acc as (
    select account_key, account_id from {{ ref('dim_account') }} where account_id <> '<UNKNOWN>'
),
cash_day as (
    select account_key, date_key, sum(signed_amount) as cash_flow
    from {{ ref('fact_cash_txn') }}
    group by 1, 2
),
grid as (
    -- lưới đủ mọi ngày lịch để cộng dồn không sót giao dịch rơi vào ngày nghỉ
    select acc.account_key, acc.account_id, cal.date_key, cal.date_day, cal.is_trading_day, cal.trading_day_number,
           coalesce(cd.cash_flow, 0) as cash_flow
    from acc
    cross join cal
    left join cash_day cd on cd.account_key = acc.account_key and cd.date_key = cal.date_key
),
-- dòng tiền phát sinh trước ngày đầu tiên của lưới (nếu có) được cộng vào số dư mở đầu
cash_before as (
    select f.account_key, sum(f.signed_amount) as opening_cash
    from {{ ref('fact_cash_txn') }} f, bounds
    where f.date_key < {{ date_key('bounds.d0') }}
    group by 1
),
cash_cum as (
    select g.*,
           coalesce(cb.opening_cash, 0)
             + sum(g.cash_flow) over (partition by g.account_key order by g.date_day) as cash_balance
    from grid g
    left join cash_before cb on cb.account_key = g.account_key
),
mv as (
    select account_key, date_key, sum(market_value) as market_value
    from {{ ref('fact_position_daily') }}
    group by 1, 2
),
buy as (
    select account_key, date_key,
           sum(filled_value) filter (where side = 'B') as buy_value,
           sum(filled_value) filter (where side = 'S') as sell_value
    from {{ ref('fact_order') }}
    where is_filled
    group by 1, 2
),
last_buy as (
    -- số thứ tự phiên của lần mua khớp gần nhất tính tới ngày (bao gồm ngày đó)
    select g.account_key, g.date_key,
           max(case when b.buy_value > 0 then g.trading_day_number end)
               over (partition by g.account_key order by g.date_day) as last_buy_td
    from grid g
    left join buy b on b.account_key = g.account_key and b.date_key = g.date_key
)
select
    c.account_key,
    c.account_id,
    c.date_key,
    c.date_day,
    c.trading_day_number,
    c.cash_balance::numeric(20,2)                                   as cash_balance,
    coalesce(mv.market_value, 0)::numeric(20,2)                      as market_value,
    (c.cash_balance + coalesce(mv.market_value, 0))::numeric(20,2)   as nav,
    coalesce(b.buy_value, 0)::numeric(20,2)                          as buy_value,
    coalesce(b.sell_value, 0)::numeric(20,2)                         as sell_value,
    -- số phiên kể từ lần mua khớp gần nhất; NULL nếu chưa mua lần nào trong dữ liệu
    c.trading_day_number - lb.last_buy_td                            as sessions_since_last_buy
from cash_cum c
left join mv  on mv.account_key = c.account_key and mv.date_key = c.date_key
left join buy b on b.account_key = c.account_key and b.date_key = c.date_key
left join last_buy lb on lb.account_key = c.account_key and lb.date_key = c.date_key
where c.is_trading_day
