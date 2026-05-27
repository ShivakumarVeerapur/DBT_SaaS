{% snapshot snp_users %}

{{
   config(
       target_database='fx-project-shiva-26',
       target_schema='snapshots',
       unique_key='user_id',
       strategy='check',
       check_cols=['plan_type', 'country']
   )
}}

select * from {{ ref('stg_users') }}

{% endsnapshot %}
