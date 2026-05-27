with days as (
    
    select
        date_day
    from {{ ref('dim_dates') }}

)

select
    date_day as date_day
from days
