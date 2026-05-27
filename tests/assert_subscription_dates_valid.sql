select *
from {{ ref('stg_subscriptions') }}
where end_date is not null
  and end_date < start_date