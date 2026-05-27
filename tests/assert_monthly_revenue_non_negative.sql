select *
from {{ ref('fct_subscriptions') }}
where monthly_revenue < 0