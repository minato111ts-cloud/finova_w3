-- K3. Giá trị khớp theo segment tại ngày đặt lệnh so với segment hiện tại (giá trị của SCD2)
select c_luc_dat.segment as segment_luc_dat, c_nay.segment as segment_hien_tai,
       count(*) as so_lenh_khop, sum(f.filled_value) as gia_tri_khop
from {{ ref('fact_order') }} f
join {{ ref('dim_customer') }} c_luc_dat on c_luc_dat.customer_key = f.customer_key
join {{ ref('dim_customer') }} c_nay     on c_nay.customer_id = f.customer_id and c_nay.is_current
where f.is_filled
group by 1, 2
order by 1, 2
