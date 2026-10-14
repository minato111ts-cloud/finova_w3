-- As-of: chỉ thấy khóa hệ thống đã biết tại cutoff. current_setting báo lỗi khi phiên chưa đặt cutoff
select * from {{ ref('hub_customer') }}
where ingested_ts <= current_setting('finova.asof_cutoff')::timestamptz
