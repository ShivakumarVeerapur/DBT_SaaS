with source as (

    select * from {{ source('raw', 'events') }}
    
)

select
    cast(event_id as integer) as event_id,
    cast(user_id as integer) as user_id,
    lower(trim(event_type)) as event_type,
    parse_timestamp('%d.%m.%y %H:%M', event_timestamp) as event_timestamp
from source
