-- Grain: 1 dòng = 1 tài khoản (SCD1: ghi đè), cộng 1 dòng "không xác định"
select
    {{ hash_key(['account_id']) }}  as account_key,
    account_id,
    customer_id,                     -- khóa bền của khách, dùng nối với dim_customer
    branch_code,
    account_type,
    case account_type when 'KYQUY' then 'Ký quỹ' else 'Thường' end as account_type_name,
    open_date
from {{ ref('stg_luyen_tap__accounts') }}
union all
select {{ unknown_key() }}, '<UNKNOWN>', null, null, null, 'Không xác định', null
