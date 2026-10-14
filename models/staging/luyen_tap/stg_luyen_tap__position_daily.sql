select
    snapshot_date,
    upper(trim(account_id))      as account_id,
    upper(trim(symbol))          as symbol,
    total_qty,
    receiving_qty,
    close_price::numeric(18,2)   as close_price
from {{ source('luyen_tap', 'position_daily') }}
