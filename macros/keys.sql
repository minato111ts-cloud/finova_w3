{#- Khóa băm SHA-256 kiểu bytea, cùng quy ước INV-M1 của Finova; không dùng dbt_utils.generate_surrogate_key -#}
{% macro hash_key(cols) -%}
sha256(convert_to(concat_ws('||'{%- for c in cols %}, coalesce(({{ c }})::text, '<NULL>'){%- endfor %}), 'UTF8'))
{%- endmacro %}

{#- Khóa của thành viên "không xác định" trong mọi dimension -#}
{% macro unknown_key() -%}
{{ hash_key(["'<UNKNOWN>'"]) }}
{%- endmacro %}

{#- Quy đổi timestamptz sang ngày theo múi giờ Việt Nam, ghi tường minh -#}
{% macro local_date(ts) -%}
({{ ts }} at time zone '{{ var("tz") }}')::date
{%- endmacro %}

{#- Khóa ngày dạng số YYYYMMDD -#}
{% macro date_key(d) -%}
to_char({{ d }}, 'YYYYMMDD')::int
{%- endmacro %}
