{#- GT-SAT-NOREDUNDANT: hai phiên bản liền nhau của cùng khóa không được cùng hash_diff (mức warn, ADR-016 Q15) -#}
{% test dv_no_redundant_versions(model, parent_hk) %}
with s as (
    select {{ parent_hk }}, ingested_ts, hash_diff,
           lag(hash_diff) over (partition by {{ parent_hk }} order by ingested_ts) as prev_hd
    from {{ model }}
)
select * from s where hash_diff = prev_hd
{% endtest %}

{#- GT-HUB-NOMASTER: đếm khóa của hub chưa có satellite của nguồn làm chủ (mức warn) -#}
{% test dv_has_master_satellite(model, column_name, satellite) %}
select h.{{ column_name }}
from {{ model }} h
where not exists (select 1 from {{ satellite }} s where s.{{ column_name }} = h.{{ column_name }})
{% endtest %}
