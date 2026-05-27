with active_users as (

    select distinct
        user_id,
        month_start
    from {{ ref('fct_subscriptions') }}

),

events as (

    select
        user_id,
        cast(event_timestamp as date) as event_date
    from {{ ref('stg_events') }}

),

final as (

    select
        a.user_id,
        a.month_start,
        case
            when count(e.event_date) > 0 then 1
            else 0
        end as has_event_last_30d_flag,
        count(e.event_date) as events_last_30d_count
    from active_users a
    left join events e
      on a.user_id = e.user_id
     and e.event_date between
         date_sub(date_sub(date_add(a.month_start, interval 1 month), interval 1 day), interval 29 day)
         and date_sub(date_add(a.month_start, interval 1 month), interval 1 day)
    group by 1, 2
)

select * from final