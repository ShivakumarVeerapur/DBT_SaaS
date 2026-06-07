{{
  config(
    materialized='incremental',
    unique_key=['subscription_id', 'month_start', 'dbt_valid_from'],
    on_schema_change='sync_all_columns'
  )
}}


with subscription_months as (

    select
        subscription_id,
        user_id,
        month_start,
        start_date,
        end_date,
        monthly_price,
        dbt_valid_from,
        dbt_valid_to
    from {{ ref('int_subscription_months') }}

)

select
    subscription_id,
    user_id,
    month_start,
    start_date,
    end_date,
    monthly_price,
    dbt_valid_from,
    dbt_valid_to,

    1 as active_flag,

    monthly_price as monthly_revenue,

    case
        when date_trunc(start_date, month) = month_start
             and end_date is not null
             and date_trunc(end_date, month) = month_start
            then 'new_and_churned'
        when date_trunc(start_date, month) = month_start
            then 'new'
        when end_date is not null
             and date_trunc(end_date, month) = month_start
            then 'churned'
        else 'active'
    end as subscription_status,

    case
        when date_trunc(start_date, month) = month_start then 1
        else 0
    end as new_subscriber_flag,

    case
        when end_date is not null
         and date_trunc(end_date, month) = month_start then 1
        else 0
    end as churned_subscriber_flag

from subscription_months

{% if is_incremental() %}
  -- Use dbt_valid_from (not month_start) so that:
  -- (a) New subscriptions with future months are picked up
  -- (b) Price changes on EXISTING months are also picked up
  -- month_start filter would miss (b) entirely.
  where dbt_valid_from > (select max(dbt_valid_from) from {{ this }})
{% endif %}

