-- Đối soát: thay đổi total_qty giữa hai ngày chụp liên tiếp = khối lượng khớp ròng trong ngày
-- Bảng chụp thưa: tài khoản × mã vắng mặt nghĩa là total_qty = 0
with days as (
    select distinct snapshot_date from {{ ref('fact_position_daily') }}
),
pairs as (
    select distinct account_id, symbol from {{ ref('fact_position_daily') }}
),
grid as (
    select p.account_id, p.symbol, d.snapshot_date,
           lag(d.snapshot_date) over (partition by p.account_id, p.symbol order by d.snapshot_date) as prev_date
    from pairs p cross join days d
),
qty as (
    select g.account_id, g.symbol, g.snapshot_date, g.prev_date,
           coalesce(cur.total_qty, 0)  as qty_cur,
           coalesce(prv.total_qty, 0)  as qty_prev
    from grid g
    left join {{ ref('fact_position_daily') }} cur
      on cur.account_id = g.account_id and cur.symbol = g.symbol and cur.snapshot_date = g.snapshot_date
    left join {{ ref('fact_position_daily') }} prv
      on prv.account_id = g.account_id and prv.symbol = g.symbol and prv.snapshot_date = g.prev_date
    where g.prev_date is not null
),
net as (
    select o.order_id, a.account_id, o.symbol, d.date_day, o.side, o.filled_qty
    from {{ ref('fact_order') }} o
    join {{ ref('dim_account') }} a on a.account_key = o.account_key
    join {{ ref('dim_date') }} d on d.date_key = o.date_key
    where o.is_filled
)
select q.account_id, q.symbol, q.snapshot_date, q.qty_prev, q.qty_cur,
       coalesce(sum(case n.side when 'B' then n.filled_qty else -n.filled_qty end), 0) as khop_rong
from qty q
left join net n
  on n.account_id = q.account_id and n.symbol = q.symbol
 and n.date_day > q.prev_date and n.date_day <= q.snapshot_date
group by q.account_id, q.symbol, q.snapshot_date, q.qty_prev, q.qty_cur
having q.qty_cur - q.qty_prev <> coalesce(sum(case n.side when 'B' then n.filled_qty else -n.filled_qty end), 0)
