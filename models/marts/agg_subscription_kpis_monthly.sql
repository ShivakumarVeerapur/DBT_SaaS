with subscriptions as (

    select
        month_start,
        user_id,
        monthly_revenue,
        new_subscriber_flag,
        churned_subscriber_flag
    from {{ ref('fct_subscriptions') }}

),

activity as (

    select
        month_start,
        user_id,
        has_event_last_30d_flag
    from {{ ref('fct_user_activity_monthly') }}

),

sub_metrics as (

    select
        month_start,
        count(distinct user_id) as active_subscribers,
        count(distinct case when new_subscriber_flag = 1 then user_id end) as new_subscribers,
        count(distinct case when churned_subscriber_flag = 1 then user_id end) as churned_subscribers,
        sum(monthly_revenue) as mrr
    from subscriptions
    group by 1
),

usage_metrics as (

    select
        month_start,
        count(distinct user_id) as active_users_for_usage,
        count(distinct case when has_event_last_30d_flag = 1 then user_id end) as active_users_with_last_30d_events
    from activity
    group by 1
)

select
    s.month_start,
    s.mrr,
    s.active_subscribers,
    s.new_subscribers,
    s.churned_subscribers,
    case
        when lag(s.active_subscribers) over (order by s.month_start) = 0 then null
        else s.churned_subscribers * 1.0
             / lag(s.active_subscribers) over (order by s.month_start)
    end as churn_rate,
    case
        when u.active_users_for_usage = 0 then null
        else u.active_users_with_last_30d_events * 1.0 / u.active_users_for_usage
    end as usage_proxy_pct
from sub_metrics s
left join usage_metrics u
    on s.month_start = u.month_start