-- Mọi nút từ cấp chi nhánh trở xuống phải quy được về một khu vực
select branch_code, branch_level, region_code
from {{ ref('dim_branch') }}
where branch_code <> '<UNKNOWN>' and branch_level >= 2 and region_code is null
