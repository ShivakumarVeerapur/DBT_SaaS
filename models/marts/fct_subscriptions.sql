{{
  config(
    materialized='incremental',
    unique_key=['subscription_id', 'month_start'],
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
        monthly_price
    from {{ ref('int_subscription_months') }}

)

select
    subscription_id,
    user_id,
    month_start,
    start_date,
    end_date,
    monthly_price,

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
  where month_start > (select max(t.month_start) from {{ this }} t)
{% endif %}

