{#- Môi trường prod: dùng đúng tên schema khai báo (staging, atomic, asof, mart).
    Môi trường khác: thêm tiền tố schema của người chạy (hv01_staging…) để không giẫm lên nhau. -#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
