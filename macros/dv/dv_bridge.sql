{#- Mẫu nạp T-BRIDGE :
    Dựng bảng Bridge tại thời điểm cutoff của ngày D.
    - Lọc bản ghi nguồn có ingested_ts <= cutoff_ts của ngày D.
    - Khử trùng theo grain_hk (giữ bản ghi có ingested_ts sớm nhất) để đảm bảo tính idempotent khi nạp lại. -#}

{% macro dv_bridge(grain_hk, hk_cols, source) -%}
with w as (
    select *
    from {{ ref(source) }}
    where ingested_ts <= {{ get_asof_cutoff() }}
      and {{ grain_hk }} is not null
)
select distinct on (w.{{ grain_hk }})
    {{ get_asof_date() }}   as as_of_date,
    w.{{ grain_hk }},
    {%- for c in hk_cols %}
    w.{{ c }},
    {%- endfor %}
    {{ get_asof_cutoff() }} as cutoff_ts
from w
order by w.{{ grain_hk }}, w.ingested_ts
{%- endmacro %}
