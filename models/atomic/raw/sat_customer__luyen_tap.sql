-- Grain: 1 dòng = 1 phiên bản thuộc tính khách, theo thời điểm hệ thống biết (ingested_ts)
{{ dv_sat(parent_hk='customer_hk', hd='sat_customer__luyen_tap_hd',
          attrs=['segment', 'kyc_status'], source='stg_luyen_tap__customers') }}
