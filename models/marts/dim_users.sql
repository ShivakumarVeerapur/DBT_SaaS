select
    user_id,
    signup_date,
    country,
    plan_type
from {{ ref('stg_users') }}