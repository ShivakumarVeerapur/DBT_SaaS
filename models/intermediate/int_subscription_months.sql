{{
  config(
    materialized='incremental',
    unique_key=['subscription_id', 'month_start', 'dbt_valid_from'],
    on_schema_change='sync_all_columns'
  )
}}

-- Reads from snp_subscriptions (the SCD Type 2 snapshot), NOT stg_subscriptions.
--
-- WHY the snapshot instead of staging?
--   stg_subscriptions = current state only (e.g. monthly_price = 60 today)
--   snp_subscriptions = full history (row for 50, row for 60 with timestamps)
--   Reading from staging loses all price history. Reading from the snapshot
--   means every month's MRR reflects what the customer was actually paying then.
--
-- WHY incremental here?
--   The snapshot table only grows (new rows appended on each dbt snapshot run).
--   We only need to expand the NEW snapshot rows into monthly records — not
--   rebuild the entire history from scratch on every dbt run.

with snapshot_subscriptions as (

    select
        subscription_id,
        user_id,
        start_date,
        end_date,
        monthly_price,
        dbt_valid_from,
        dbt_valid_to
    from {{ ref('snp_subscriptions') }}

    {% if is_incremental() %}
    -- On incremental runs: only pick up snapshot rows that are newer than
    -- what we have already processed. dbt_valid_from is the exact timestamp
    -- the snapshot recorded this version of the row.
    where dbt_valid_from > (
        select max(dbt_valid_from) from {{ this }}
    )
    {% endif %}

),

calendar as (

    select date_day
    from {{ ref('int_calendar_dates') }}

),

bounds as (

    select max(date_day) as max_date
    from calendar

),

months as (

    select distinct
        date_trunc(date_day, month) as month_start
    from calendar

),

expanded as (

    select
        s.subscription_id,
        s.user_id,
        s.start_date,
        s.end_date,
        s.monthly_price,
        s.dbt_valid_from,
        s.dbt_valid_to,
        m.month_start
    from snapshot_subscriptions s
    cross join bounds b
    join months m
      on m.month_start >= date_trunc(s.start_date, month)
     -- Cap at end_date or at dbt_valid_to (whichever comes first)
     -- This prevents a superseded price version from bleeding into future months
     and m.month_start <= date_trunc(
             coalesce(
                 s.end_date,
                 if(s.dbt_valid_to is not null, date(s.dbt_valid_to), b.max_date)
             ), month)

)

select
    subscription_id,
    user_id,
    start_date,
    end_date,
    monthly_price,
    dbt_valid_from,
    dbt_valid_to,
    month_start
from expanded