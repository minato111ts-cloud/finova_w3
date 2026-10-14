-- K1. Giá trị khớp theo khu vực × tuần
select b.region_name, d.week_start, sum(f.filled_value) as gia_tri_khop
from {{ ref('fact_order') }} f
join {{ ref('dim_branch') }} b on b.branch_key = f.branch_key
join {{ ref('dim_date') }} d   on d.date_key = f.date_key
where f.is_filled
group by 1, 2
order by 1, 2
