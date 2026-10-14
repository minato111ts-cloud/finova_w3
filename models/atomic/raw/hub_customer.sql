-- Grain: 1 dòng = 1 khách hàng. Nhận khóa từ mọi staging mang khóa khách (DEC-ELT-HUBSRC)
{{ dv_hub(hk='customer_hk', bk='customer_id',
          sources=['stg_luyen_tap__customers', 'stg_luyen_tap__accounts']) }}
