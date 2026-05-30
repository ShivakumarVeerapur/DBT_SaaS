{% snapshot snp_subscriptions %}

{{
   config(
       target_database='fx-project-shiva-26',
       target_schema='snapshots',
       unique_key='subscription_id',
       strategy='check',
       check_cols=['monthly_price', 'end_date']
   )
}}

select * from {{ ref('stg_subscriptions') }}

{% endsnapshot %}
