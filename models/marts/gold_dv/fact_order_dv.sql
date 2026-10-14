-- Grain: 1 dòng = 1 lệnh. Phiên bản khách tại ngày đặt lệnh lấy qua bridge và PIT của đúng ngày đó
with o as (
    select * from {{ ref('nhl_order') }}
),
b as (
    select * from {{ ref('bridge_customer_account') }}
),
p as (
    select * from {{ ref('pit_customer_daily') }}
)
select
    o.order_id,
    {{ date_key('o.trade_date') }}                                       as date_key,
    o.order_ts,
    o.account_hk,
    b.customer_hk,
    case when p.sat_customer__luyen_tap_ingested_ts is null then {{ unknown_key() }}
         else {{ hash_key([fmt_hk('p.customer_hk'), fmt_ts('p.sat_customer__luyen_tap_ingested_ts')]) }}
    end                                                                  as customer_key,
    o.instrument_hk,
    o.side,
    o.status,
    o.status = 'FILLED'                                                  as is_filled,
    case when o.status = 'FILLED' then (o.quantity * o.price)::numeric(20,2) else 0 end as filled_value
from o
left join b on b.account_hk = o.account_hk and b.as_of_date = o.trade_date
left join p on p.customer_hk = b.customer_hk and p.as_of_date = o.trade_date
