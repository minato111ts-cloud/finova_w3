-- singular test
-- HV4 Singular Test: bridge_customer_account
-- Sô dòng bridge ngày D bằng số dòng link có ingested_ts <= cutoff_ts của D
-- cutoff_ts: Hiểu đơn giản là thời gian tiến hành capture data để tiến hành xuất báo cáo 
-- => Với ingested_ts <= cutoff_ts thì số dòng link và bridge sẽ phải bằng nhau để đảm bảo tính đồng nhất dữ liệu

with bridge_per_day as (
    select
        as_of_date,
        cutoff_ts,
        count(*) as bridge_cnt
    from {{ ref('bridge_customer_account') }}
    group by
        as_of_date,
        cutoff_ts
),

link_per_day as (
    select
        b.as_of_date,
        b.cutoff_ts,
        b.bridge_cnt,
        count(l.link_customer_account_hk) as link_cnt
    from bridge_per_day b
    left join {{ ref('link_customer_account') }} l
        on l.ingested_ts <= b.cutoff_ts
    group by
        b.as_of_date,
        b.cutoff_ts,
        b.bridge_cnt
)

select
    as_of_date,
    cutoff_ts,
    bridge_cnt,
    link_cnt
from link_per_day
where bridge_cnt <> link_cnt