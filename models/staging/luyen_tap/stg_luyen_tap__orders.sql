-- trade_date lấy theo giờ Việt Nam, ghi tường minh múi giờ (không dùng order_ts::date)
select
    o.*,
    {{ dv_hk(['o.order_id']) }}      as order_hk,
    {{ dv_hk(['o.account_id']) }}    as account_hk,
    {{ dv_hk(['o.symbol']) }}        as instrument_hk,
    {{ replay_ingested_ts('o.trade_date') }}                    as ingested_ts,
    o.order_ts                                                  as event_ts,
    'luyen_tap.orders'::text                                    as record_source
from (
    select
        upper(trim(order_id))                          as order_id,
        upper(trim(account_id))                        as account_id,
        upper(trim(symbol))                            as symbol,
        upper(trim(side))                              as side,
        quantity,
        price::numeric(18,2)                           as price,
        order_ts,
        {{ local_date('order_ts') }}                   as trade_date,
        (order_ts at time zone '{{ var("tz") }}')::time < time '09:00'  as is_pre_session,
        upper(trim(status))                            as status
    from {{ source('luyen_tap', 'orders') }}
) o
