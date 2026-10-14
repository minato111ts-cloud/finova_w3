-- Hai phiên bản của cùng một khách không được chồng khoảng hiệu lực
select a.customer_id, a.valid_from, a.valid_to, b.valid_from as valid_from_2
from {{ ref('dim_customer') }} a
join {{ ref('dim_customer') }} b
  on a.customer_id = b.customer_id
 and a.customer_key <> b.customer_key
 and a.valid_from < b.valid_to
 and b.valid_from < a.valid_to
where a.customer_id <> '<UNKNOWN>'
