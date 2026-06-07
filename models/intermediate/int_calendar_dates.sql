{{
  config(materialized='ephemeral')
}}

-- Ephemeral: dbt inlines this as a CTE inside any model that ref()'s it.
-- No BigQuery table or view is created. Zero storage cost.
-- To see the dates it generates, query intermediate.int_subscription_months.

with user_dates as (

    select
        min(signup_date) as min_date,
        max(signup_date) as max_date
    from {{ ref('stg_users') }}

),

subscription_dates as (

    select
        min(start_date)  as min_date,
        max(end_date)    as max_date   -- only real end dates; active subs (null) are excluded
    from {{ ref('stg_subscriptions') }}

),

bounds as (

    select
        least(u.min_date, s.min_date) as start_date,
        greatest(u.max_date, s.max_date) as end_date
    from user_dates u
    cross join subscription_dates s

),

calendar as (

    select
        day as date_day
    from bounds,
    unnest(generate_date_array(start_date, end_date, interval 1 day)) as day

)

select
    date_day
from calendar
