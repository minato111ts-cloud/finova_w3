-- Grain: 1 dòng = 1 lệnh. Non-historized link: lệnh trong dữ liệu tập là sự kiện bất biến
{{ dv_link(hk='order_hk',
           cols=['account_hk', 'instrument_hk', 'order_id', 'side', 'quantity', 'price', 'status', 'order_ts', 'trade_date'],
           source='stg_luyen_tap__orders') }}
