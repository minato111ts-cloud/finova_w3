-- Grain: 1 dòng = 1 nút của cây tổ chức, cộng 1 dòng "không xác định"
-- Khu vực tính bằng đệ quy, không phụ thuộc độ sâu cây và không ghi cứng mã 'HO'
with recursive src as (
    select * from {{ ref('stg_luyen_tap__branches') }}
),
tree as (
    select
        branch_code, branch_name, parent_code,
        0                              as branch_level,
        branch_code::text              as branch_path,
        array[branch_code]             as path_arr,
        null::text                     as region_code
    from src
    where parent_code is null
    union all
    select
        s.branch_code, s.branch_name, s.parent_code,
        t.branch_level + 1,
        t.branch_path || ' > ' || s.branch_code,
        t.path_arr || s.branch_code,
        case when t.branch_level = 0 then s.branch_code else t.region_code end
    from src s
    join tree t on s.parent_code = t.branch_code
    where not s.branch_code = any(t.path_arr)          -- chặn vòng khi dữ liệu bẩn
)
select
    {{ hash_key(['t.branch_code']) }}  as branch_key,
    t.branch_code,
    t.branch_name,
    t.parent_code,
    t.branch_level,
    case t.branch_level when 0 then 'Hội sở' when 1 then 'Khu vực'
                        when 2 then 'Chi nhánh' else 'Phòng giao dịch' end as level_name,
    t.branch_path,
    t.region_code,
    r.branch_name                      as region_name
from tree t
left join src r on r.branch_code = t.region_code
union all
select {{ unknown_key() }}, '<UNKNOWN>', 'Không xác định', null, null, 'Không xác định', null, null, null
