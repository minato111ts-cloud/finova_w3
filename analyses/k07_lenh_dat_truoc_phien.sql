-- K7. Lệnh đặt trước phiên (trước 09:00 giờ Việt Nam): ngày theo giờ Việt Nam và theo UTC
select d.date_day as ngay_gd_vn,
       (f.order_ts at time zone 'UTC')::date as ngay_theo_utc,
       count(*) as so_lenh
from {{ ref('fact_order') }} f
join {{ ref('dim_date') }} d on d.date_key = f.date_key
where f.is_pre_session
group by 1, 2
order by 1
