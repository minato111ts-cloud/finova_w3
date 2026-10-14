-- Tổng số lệnh và tổng giá trị khớp ở fact phải bằng nguồn (không mất, không nhân dòng khi join dim)
with f as (
    select count(*) as so_lenh, sum(filled_value) as gia_tri_khop from {{ ref('fact_order') }}
),
s as (
    select count(*) as so_lenh,
           sum(case when status = 'FILLED' then quantity * price else 0 end) as gia_tri_khop
    from {{ ref('stg_luyen_tap__orders') }}
)
select * from f, s
where f.so_lenh <> s.so_lenh or f.gia_tri_khop <> s.gia_tri_khop
