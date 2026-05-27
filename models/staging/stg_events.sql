{{
  config(
    materialized='incremental',
    unique_key='event_id'
  )
}}

with source as (

    select * from {{ ref('event') }}

)

select
    cast(event_id as integer) as event_id,
    cast(user_id as integer) as user_id,
    lower(trim(event_type)) as event_type,
    parse_timestamp('%d.%m.%y %H:%M', event_timestamp) as event_timestamp
from source

{% if is_incremental() %}
  where parse_timestamp('%d.%m.%y %H:%M', event_timestamp) > (select max(event_timestamp) from {{ this }})
{% endif %}