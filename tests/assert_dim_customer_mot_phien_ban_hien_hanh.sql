-- Mỗi khách có đúng một phiên bản hiện hành
select customer_id, count(*) filter (where is_current) as so_hien_hanh
from {{ ref('dim_customer') }}
where customer_id <> '<UNKNOWN>'
group by customer_id
having count(*) filter (where is_current) <> 1
