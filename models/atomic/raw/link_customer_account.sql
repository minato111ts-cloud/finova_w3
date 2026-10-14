-- Grain: 1 dòng = 1 cặp khách × tài khoản. Link chỉ có khóa
{{ dv_link(hk='link_customer_account_hk', cols=['customer_hk', 'account_hk'],
           source='stg_luyen_tap__accounts') }}
