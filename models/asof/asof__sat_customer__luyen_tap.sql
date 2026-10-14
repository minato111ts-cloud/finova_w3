-- As-of satellite: mỗi khóa lấy phiên bản có ingested_ts lớn nhất ≤ cutoff (ADR-016 Q15)
select distinct on (customer_hk) *
from {{ ref('sat_customer__luyen_tap') }}
where ingested_ts <= current_setting('finova.asof_cutoff')::timestamptz
order by customer_hk, ingested_ts desc
