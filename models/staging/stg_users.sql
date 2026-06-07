with source as (

    select * from {{ source('raw', 'users') }}

)

select
    cast(user_id as integer) as user_id,
    parse_date('%d.%m.%y', signup_date) as signup_date,
    upper(trim(country)) as country,
    lower(trim(plan_type)) as plan_type
from source