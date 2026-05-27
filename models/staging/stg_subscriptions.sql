with source as (

    select * from {{ ref('Subscriptions') }}

)

select
    cast(subscription_id as integer) as subscription_id,
    cast(user_id as integer) as user_id,
    parse_date('%d.%m.%y', start_date) as start_date,
    case
        when end_date = '' then null
        else parse_date('%d.%m.%y', end_date)
    end as end_date,
    cast(monthly_price as float64) as monthly_price
from source