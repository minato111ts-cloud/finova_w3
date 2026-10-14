{#- Mẫu nạp Data Vault viết thành macro (FNV-ELT-SLV-TQ §6.2). Model chỉ còn khai báo cột. -#}

{#- T-HUB: hợp khóa từ mọi staging mang khóa, chèn khóa chưa có, giữ ingested_ts lần thấy đầu -#}
{% macro dv_hub(hk, bk, sources) -%}
with src as (
    {%- for s in sources %}
    select {{ hk }}, '{{ var("bkcc") }}'::text as bkcc, {{ bk }}, ingested_ts, event_ts, record_source
    from {{ ref(s) }}
    {%- if not loop.last %}
    union all
    {%- endif %}
    {%- endfor %}
),
w as (
    select * from src
    where {{ dv_window() }} and {{ hk }} is not null
)
select distinct on (w.{{ hk }})
       w.{{ hk }}, w.bkcc, w.{{ bk }}, w.ingested_ts, w.event_ts, w.record_source
from w
{%- if is_incremental() %}
where not exists (select 1 from {{ this }} t where t.{{ hk }} = w.{{ hk }})
{%- endif %}
order by w.{{ hk }}, w.ingested_ts, w.record_source
{%- endmacro %}

{#- T-LINK và T-NHL: như T-HUB trên một staging; cols là khóa hub (link) hoặc khóa + nội dung bất biến (nhl) -#}
{% macro dv_link(hk, cols, source) -%}
with w as (
    select * from {{ ref(source) }}
    where {{ dv_window() }} and {{ hk }} is not null
)
select distinct on (w.{{ hk }})
       w.{{ hk }}, {% for c in cols %}w.{{ c }}, {% endfor %}w.ingested_ts, w.event_ts, w.record_source
from w
{%- if is_incremental() %}
where not exists (select 1 from {{ this }} t where t.{{ hk }} = w.{{ hk }})
{%- endif %}
order by w.{{ hk }}, w.ingested_ts, w.record_source
{%- endmacro %}

{#- T-SAT: ghi phiên bản khi hash_diff khác phiên bản liền trước (INV-T3: A → B → A ra 3 phiên bản) -#}
{% macro dv_sat(parent_hk, hd, attrs, source) -%}
with w as (
    select {{ parent_hk }}, ingested_ts, event_ts, {{ hd }} as hash_diff, record_source
           {%- for a in attrs %}, {{ a }}{% endfor %}
    from {{ ref(source) }}
    where {{ dv_window() }} and {{ parent_hk }} is not null
),
v as (   -- bỏ dòng trùng nguyên nội dung cùng thời điểm
    select distinct on ({{ parent_hk }}, ingested_ts, hash_diff) *
    from w
    order by {{ parent_hk }}, ingested_ts, hash_diff, event_ts
),
cur as ( -- phiên bản mới nhất đã có trong vault của các khóa trong cửa sổ
    {%- if is_incremental() %}
    select distinct on (t.{{ parent_hk }}) t.{{ parent_hk }}, t.hash_diff
    from {{ this }} t
    where t.{{ parent_hk }} in (select {{ parent_hk }} from v)
    order by t.{{ parent_hk }}, t.ingested_ts desc
    {%- else %}
    select null::bytea as {{ parent_hk }}, null::bytea as hash_diff where false
    {%- endif %}
),
seq as (
    select v.*, lag(v.hash_diff) over (partition by v.{{ parent_hk }} order by v.ingested_ts) as prev_hd
    from v
)
select seq.{{ parent_hk }}, seq.ingested_ts, seq.event_ts, seq.hash_diff, seq.record_source
       {%- for a in attrs %}, seq.{{ a }}{% endfor %}
from seq
left join cur on cur.{{ parent_hk }} = seq.{{ parent_hk }}
where seq.hash_diff is distinct from coalesce(seq.prev_hd, cur.hash_diff)
{%- endmacro %}
