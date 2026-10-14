select
    c.*,
    {{ dv_hk(['c.account_id']) }}   as account_hk,
    {{ replay_ingested_ts('c.txn_date') }}                      as ingested_ts,
    c.txn_ts                                                    as event_ts,
    'luyen_tap.cash_txn'::text                                  as record_source
from (
    select
        upper(trim(txn_id))                 as txn_id,
        upper(trim(account_id))             as account_id,
        txn_ts,
        {{ local_date('txn_ts') }}          as txn_date,
        upper(trim(txn_type))               as txn_type,
        amount::numeric(20,2)               as amount,
        nullif(upper(trim(ref_order_id)), '') as ref_order_id
    from {{ source('luyen_tap', 'cash_txn') }}
) c
