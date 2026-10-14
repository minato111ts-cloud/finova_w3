{#- Minh họa dbt snapshot: chụp trạng thái hiện hành mỗi lần chạy `dbt snapshot`.
    dbt_valid_from là giờ chạy, không phải lúc hệ thống biết bản ghi: lịch sử trước lần chụp đầu bị mất. -#}
{% snapshot snap_customer_current %}
{{ config(unique_key='customer_id', strategy='check', check_cols=['segment', 'kyc_status']) }}
select distinct on (customer_id) customer_id, segment, kyc_status, updated_at
from {{ ref('stg_luyen_tap__customers') }}
order by customer_id, updated_at desc
{% endsnapshot %}
