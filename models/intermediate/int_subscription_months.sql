with subscriptions as (

    select
        subscription_id,
        user_id,
        start_date,
        end_date,
        monthly_price
    from {{ ref('stg_subscriptions') }}

),

calendar as (

    select
        date_day
    from {{ ref('int_calendar_dates') }}

),

bounds as (

    select
        max(date_day) as max_date
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
        m.month_start
    from subscriptions s
    cross join bounds b
    join months m
      on m.month_start >= date_trunc(s.start_date, month)
     and m.month_start <= date_trunc(coalesce(s.end_date, b.max_date), month)

)

select
    subscription_id,
    user_id,
    start_date,
    end_date,
    monthly_price,
    month_start
from expanded