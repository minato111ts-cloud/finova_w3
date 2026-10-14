-- Chuẩn hóa mã chi nhánh; không chứa logic nghiệp vụ
select
    upper(trim(branch_code))                 as branch_code,
    trim(branch_name)                        as branch_name,
    nullif(upper(trim(parent_code)), '')     as parent_code
from {{ source('luyen_tap', 'branches') }}
