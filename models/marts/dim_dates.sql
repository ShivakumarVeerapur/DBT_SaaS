with dates as (

    select
        date_day
    from {{ ref('int_calendar_dates') }}

)

select
    date_day,
    date_trunc(date_day, month) as month_start,
    extract(year from date_day) as year_num,
    extract(month from date_day) as month_num,
    format_date('%Y-%m', date_day) as year_month
from dates