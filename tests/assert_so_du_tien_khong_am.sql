-- Số dư tiền đã thanh toán không được âm ở bất kỳ ngày nào
select account_id, date_day, cash_balance
from {{ ref('mart_account_daily') }}
where cash_balance < 0
