select
    a.account_id,
    a.customer_id,
    a.branch_code,
    a.account_type,
    a.open_date,
    -- cột cho Data Vault; link_hk băm từ khóa nghiệp vụ, không băm lại từ hk của hub (DEC-ELT-LINKHK)
    {{ dv_hk(['a.account_id']) }}  as account_hk,
    {{ dv_hk(['a.customer_id']) }}  as customer_hk,
    {{ dv_hk(['a.customer_id', 'a.account_id']) }}  as link_customer_account_hk,
    {{ hash_key(['a.account_type', fmt_date('a.open_date')]) }}  as sat_account__luyen_tap_hd,
    {{ replay_ingested_ts('a.open_date') }}  as ingested_ts,
    (a.open_date::timestamp at time zone '{{ var("tz") }}')                                           as event_ts,
    'luyen_tap.accounts'::text                                                                       as record_source
from (
    select
        upper(trim(account_id))    as account_id,
        upper(trim(customer_id))   as customer_id,
        upper(trim(branch_code))   as branch_code,
        upper(trim(account_type))  as account_type,
        open_date
    from {{ source('luyen_tap', 'accounts') }}
) a
