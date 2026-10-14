-- K10. Nạp – rút ròng theo khu vực
select coalesce(b.region_name, 'Không xác định') as khu_vuc,
       sum(f.signed_amount) filter (where f.txn_type = 'DEPOSIT')  as nap,
       -sum(f.signed_amount) filter (where f.txn_type = 'WITHDRAW') as rut,
       sum(f.signed_amount)                                         as rong
from {{ ref('fact_cash_txn') }} f
join {{ ref('dim_branch') }} b on b.branch_key = f.branch_key
where f.txn_group = 'NAP_RUT'
group by 1
order by 1
