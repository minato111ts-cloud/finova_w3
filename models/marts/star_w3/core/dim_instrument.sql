-- Grain: 1 dòng = 1 mã chứng khoán, cộng 1 dòng "không xác định" cho mã không có trong danh mục
select
    {{ hash_key(['symbol']) }}  as instrument_key,
    symbol,
    instrument_name,
    exchange,
    sector,
    listing_date
from {{ ref('stg_luyen_tap__instruments') }}
union all
select {{ unknown_key() }}, '<UNKNOWN>', 'Không xác định', null, 'Không xác định', null
