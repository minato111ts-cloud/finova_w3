-- K4. Năm tài khoản có NAV lớn nhất tại phiên cuối kỳ
select m.account_id, m.cash_balance, m.market_value, m.nav
from {{ ref('mart_account_daily') }} m
where m.date_day = (select max(date_day) from {{ ref('mart_account_daily') }})
order by m.nav desc, m.account_id
limit 5
