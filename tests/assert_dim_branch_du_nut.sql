-- Mọi nút ở staging phải có mặt trong dim_branch.
-- Đệ quy chỉ đi từ gốc xuống: nút có cha không tồn tại, hoặc nằm trong vòng, sẽ bị rơi âm thầm nếu không có test này.
select s.branch_code, s.parent_code
from {{ ref('stg_luyen_tap__branches') }} s
left join {{ ref('dim_branch') }} d on d.branch_code = s.branch_code
where d.branch_code is null
