-- K2. Giá trị khớp theo ngành × chiều lệnh
select i.sector, f.side, sum(f.filled_value) as gia_tri_khop, count(*) as so_lenh_khop
from {{ ref('fact_order') }} f
join {{ ref('dim_instrument') }} i on i.instrument_key = f.instrument_key
where f.is_filled
group by 1, 2
order by 1, 2
