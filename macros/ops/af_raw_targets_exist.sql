{#- Dùng cho DAG Airflow lab_raw_weekly: báo bảng đích raw vault (incremental) đã tồn tại hay chưa.
    Gọi: dbt run-operation af_raw_targets_exist --quiet
    In đúng một dòng: AF_RAW_TARGETS_EXIST=true khi MỌI model incremental có tag dv_raw đã có bảng, ngược lại false.
    Lần chạy đầu trên schema mới trả false -> unit test của model incremental chưa chạy được (ghi chú A7 tuần 3). -#}
{% macro af_raw_targets_exist() %}
    {%- set ns = namespace(all_exist=true, checked=0) -%}
    {%- if execute -%}
        {%- for node in graph.nodes.values() if node.resource_type == 'model'
              and 'dv_raw' in node.tags and node.config.materialized == 'incremental' -%}
            {%- set rel = adapter.get_relation(database=node.database, schema=node.schema, identifier=node.alias) -%}
            {%- set ns.checked = ns.checked + 1 -%}
            {%- if rel is none -%}{%- set ns.all_exist = false -%}{%- endif -%}
        {%- endfor -%}
        {%- if ns.checked == 0 -%}{%- set ns.all_exist = false -%}{%- endif -%}
        {%- set res = 'AF_RAW_TARGETS_EXIST=' ~ (ns.all_exist | string | lower) -%}
        {{ print(res) }}
        {{ log(res, info=True) }}
    {%- endif -%}
{% endmacro %}
