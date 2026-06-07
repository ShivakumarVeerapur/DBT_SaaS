{% snapshot snp_users_timestamp %}

{{
   config(
       target_database='fx-project-shiva-26',
       target_schema='snapshots',
       unique_key='user_id',
       strategy='timestamp',
       updated_at='signup_date'
   )
}}

select
    user_id,
    signup_date,
    country,
    plan_type,
    -- Cast DATE → TIMESTAMP so it matches what the 'timestamp' strategy expects.
    -- In production you'd use a real updated_at TIMESTAMP from the source system.
    cast(signup_date as timestamp) as updated_at
from {{ ref('stg_users') }}

{% endsnapshot %}
