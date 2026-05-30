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

select * from {{ ref('stg_users') }}

{% endsnapshot %}
