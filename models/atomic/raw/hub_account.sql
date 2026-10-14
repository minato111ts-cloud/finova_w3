-- Grain: 1 dòng = 1 tài khoản. Tài khoản chỉ thấy ở giao dịch tiền (LTA099) vẫn vào hub
{{ dv_hub(hk='account_hk', bk='account_id',
          sources=['stg_luyen_tap__accounts', 'stg_luyen_tap__orders', 'stg_luyen_tap__cash_txn']) }}
