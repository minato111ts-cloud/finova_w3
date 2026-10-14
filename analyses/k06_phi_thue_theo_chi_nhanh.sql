-- K6. Phí và thuế thu từ khách theo chi nhánh (số dương)
select b.branch_code, b.branch_name, -sum(f.signed_amount) as phi_thue
from {{ ref('fact_cash_txn') }} f
join {{ ref('dim_branch') }} b on b.branch_key = f.branch_key
where f.txn_group = 'PHI_THUE'
group by 1, 2
order by 3 desc
