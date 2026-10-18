{#- ingested_ts giả lập cho bài lab: 22:00 ngày nghiệp vụ, giờ Việt Nam (HEL-001 Phụ lục D.3, INV-T6).
    Ở Finova thật, loader gán ingested_ts một lần lúc ghi landing (INV-T2); dbt không bao giờ tự sinh. -#}
{% macro replay_ingested_ts(business_date) -%}
((({{ business_date }})::date + time '{{ var("replay_batch_time") }}') at time zone '{{ var("tz") }}')
{%- endmacro %}

{#- Cửa sổ nạp trên ingested_ts.
    lo_ts = 'auto': mốc dưới là ingested_ts lớn nhất đã có trong bảng (cách dbt thường làm).
    lo_ts = giá trị cụ thể: cửa sổ (lo, hi] do finova-cli truyền vào từ sổ chạy ctrl (DEC-ELT-WINDOW). -#}
{% macro dv_window(col='ingested_ts') -%}
{%- if var('lo_ts') == 'auto' -%}
    {%- if is_incremental() -%}
{{ col }} > (select coalesce(max(ingested_ts), '-infinity'::timestamptz) from {{ this }})
    {%- else -%}
true
    {%- endif -%}
{%- else -%}
{{ col }} > '{{ var("lo_ts") }}'::timestamptz
{%- endif %} and {{ col }} <= '{{ var("hi_ts") }}'::timestamptz
{%- endmacro %}

{#- Định dạng tường minh trước khi băm: không dựa vào ::text vì kết quả đổi theo TimeZone, DateStyle, bytea_output -#}
{% macro fmt_ts(col) -%}
to_char(({{ col }}) at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')
{%- endmacro %}
{% macro fmt_date(col) -%}
to_char({{ col }}, 'YYYY-MM-DD')
{%- endmacro %}
{% macro fmt_hk(col) -%}
encode({{ col }}, 'hex')
{%- endmacro %}

{#- Đặt ngày D và cutoff của D vào phiên (GUC). View as-of đọc hai giá trị này; chưa đặt thì báo lỗi -#}
{% macro asof_set_session() -%}
select
  set_config('finova.asof_date', '{{ var("as_of_date") }}', false),
  set_config('finova.asof_cutoff',
             ((('{{ var("as_of_date") }}'::date + 1) + time '{{ var("cutoff_time") }}') at time zone '{{ var("tz") }}')::text,
             false)
{%- endmacro %}

{#- Đọc ngày D và cutoff từ phiên; tách thành macro để có thể override trong unit_tests -#}
{% macro get_asof_date() -%}
current_setting('finova.asof_date')::date
{%- endmacro %}

{% macro get_asof_cutoff() -%}
current_setting('finova.asof_cutoff')::timestamptz
{%- endmacro %}


{#- Khóa băm Data Vault: mỗi khóa nghiệp vụ đi kèm mã hệ thống bkcc (ADR-016 Q7; link theo DEC-ELT-LINKHK) -#}
{% macro dv_hk(bk_cols) -%}
{%- set parts = [] -%}
{%- for c in bk_cols -%}
    {%- do parts.append("'" ~ var('bkcc') ~ "'") -%}
    {%- do parts.append(c) -%}
{%- endfor -%}
{{ hash_key(parts) }}
{%- endmacro %}



-- dbt build --selector lab_bv --vars "{as_of_date: '2026-03-27'}"