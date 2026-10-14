-- Grain: 1 dòng = 1 ngày lịch trong khoảng var date_start..date_end
-- Ngày giao dịch = không phải thứ 7, chủ nhật, và không nằm trong seed exchange_holidays
with spine as (
    select d::date as date_day
    from generate_series('{{ var("date_start") }}'::date, '{{ var("date_end") }}'::date, interval '1 day') as d
),
flags as (
    select
        s.date_day,
        extract(isodow from s.date_day)::int          as iso_dow,
        extract(isodow from s.date_day) >= 6          as is_weekend,
        h.holiday_date is not null                    as is_holiday,
        h.holiday_name
    from spine s
    left join {{ ref('exchange_holidays') }} h on h.holiday_date = s.date_day
),
numbered as (
    select
        *,
        not is_weekend and not is_holiday             as is_trading_day,
        -- số thứ tự phiên tính tới ngày này (ngày nghỉ giữ số của phiên liền trước)
        sum(case when not is_weekend and not is_holiday then 1 else 0 end)
            over (order by date_day)                  as trading_day_number
    from flags
),
trading as (
    select trading_day_number, date_day as trading_date
    from numbered
    where is_trading_day
)
select
    {{ date_key('n.date_day') }}                      as date_key,
    n.date_day,
    n.iso_dow,
    case n.iso_dow when 1 then 'Thứ Hai' when 2 then 'Thứ Ba' when 3 then 'Thứ Tư'
                   when 4 then 'Thứ Năm' when 5 then 'Thứ Sáu' when 6 then 'Thứ Bảy'
                   else 'Chủ nhật' end                as day_name,
    n.is_weekend,
    n.is_holiday,
    n.holiday_name,
    n.is_trading_day,
    n.trading_day_number,
    -- phiên gần nhất trước ngày này và ngày thanh toán T+2 (chỉ có nghĩa với ngày giao dịch)
    prev_td.trading_date                              as prev_trading_date,
    case when n.is_trading_day then t2.trading_date end as settlement_date_t2,
    date_trunc('week', n.date_day)::date              as week_start,
    to_char(n.date_day, 'YYYY-MM')                    as month_key
from numbered n
left join trading prev_td on prev_td.trading_day_number = n.trading_day_number - case when n.is_trading_day then 1 else 0 end
left join trading t2      on t2.trading_day_number = n.trading_day_number + 2
