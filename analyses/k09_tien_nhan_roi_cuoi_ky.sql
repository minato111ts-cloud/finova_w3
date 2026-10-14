-- K9. Tài khoản có tiền nhàn rỗi tại phiên cuối kỳ (mô phỏng điều kiện của tín hiệu S1)
-- Ngưỡng lấy từ var trong dbt_project.yml, không ghi cứng
select m.account_id, m.cash_balance, m.sessions_since_last_buy
from {{ ref('mart_account_daily') }} m
where m.date_day = (select max(date_day) from {{ ref('mart_account_daily') }})
  and m.cash_balance >= {{ var('idle_cash_min') }}
  and (m.sessions_since_last_buy >= {{ var('idle_sessions_min') }} or m.sessions_since_last_buy is null)
order by m.cash_balance desc
