-- K5. Giá trị danh mục toàn công ty: cộng theo tài khoản trong từng ngày, rồi lấy bình quân theo ngày
-- (market_value là đại lượng chụp: không cộng qua các ngày)
with ngay as (
    select date_key, sum(market_value) as tong_gia_tri
    from {{ ref('fact_position_daily') }}
    group by 1
)
select
    (select tong_gia_tri from ngay where date_key = (select max(date_key) from ngay)) as gia_tri_cuoi_ky,
    round(avg(tong_gia_tri), 0)                                                       as binh_quan_ngay,
    sum(tong_gia_tri)                                                                 as cong_sai_qua_ngay
from ngay
