select
    i.*,
    {{ dv_hk(['i.symbol']) }}  as instrument_hk,
    {{ hash_key(['i.instrument_name', 'i.exchange', 'i.sector', fmt_date('i.listing_date')]) }}  as sat_instrument__luyen_tap_hd,
    -- bảng tham chiếu nạp một lần trước kỳ dữ liệu
    {{ replay_ingested_ts("'" ~ var('initial_load_date') ~ "'") }}  as ingested_ts,
    (i.listing_date::timestamp at time zone '{{ var("tz") }}')                                          as event_ts,
    'luyen_tap.instruments'::text                                                                      as record_source
from (
    select
        upper(trim(symbol))        as symbol,
        trim(instrument_name)      as instrument_name,
        upper(trim(exchange))      as exchange,
        trim(sector)               as sector,
        listing_date
    from {{ source('luyen_tap', 'instruments') }}
) i
