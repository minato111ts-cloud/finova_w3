-- K8. Tỷ lệ lệnh khớp theo loại tài khoản
select a.account_type_name,
       count(*) as so_lenh,
       count(*) filter (where f.is_filled) as so_lenh_khop,
       round(100.0 * count(*) filter (where f.is_filled) / count(*), 1) as ty_le_khop_pct
from {{ ref('fact_order') }} f
join {{ ref('dim_account') }} a on a.account_key = f.account_key
group by 1
order by 1
