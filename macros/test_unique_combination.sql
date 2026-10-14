{#- Test generic: tổ hợp cột là duy nhất (thay cho dbt_utils.unique_combination_of_columns) -#}
{% test unique_combination(model, columns) %}
select {{ columns | join(', ') }}, count(*) as so_dong
from {{ model }}
group by {{ columns | join(', ') }}
having count(*) > 1
{% endtest %}
