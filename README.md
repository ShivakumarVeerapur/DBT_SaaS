# Subscription Analytics — dbt + BigQuery Assignment

A fully layered dbt project that transforms raw subscription, user, and event data into analytics-ready tables in BigQuery, powering a Tableau dashboard with subscription KPIs.

---

## Project Structure

```
dish_assignment/
├── seeds/                         # Raw CSV source data loaded into BigQuery
│   ├── Users.csv                  # User sign-up records
│   ├── Subscriptions.csv          # Subscription lifecycle records
│   └── event.csv                  # Product engagement events
│
├── models/
│   ├── staging/                   # 1:1 cleaned views over raw seed data
│   │   ├── stg_users.sql
│   │   ├── stg_subscriptions.sql
│   │   └── stg_events.sql
│   │
│   ├── intermediate/              # Reusable building blocks
│   │   ├── int_calendar_dates.sql        # Dynamic date spine (bounded to real data range)
│   │   └── int_subscription_months.sql   # Subscription × month expansion
│   │
│   ├── marts/                     # Final analytics tables exposed to Tableau
│   │   ├── dim_users.sql                 # User dimension
│   │   ├── dim_dates.sql                 # Date dimension
│   │   ├── fct_subscriptions.sql         # Monthly subscription fact table (MRR, churn)
│   │   ├── fct_user_activity_monthly.sql # 30-day rolling user activity
│   │   └── agg_subscription_kpis_monthly.sql # Aggregated dashboard KPIs
│   │
│   └── metric/                    # dbt Semantic Layer definitions
│       ├── semantic_models.yml
│       ├── metrics.yml
│       └── metricflow_time_spine.sql
│
├── macros/
│   └── generate_schema_name.sql   # Outputs clean schema names (staging / marts etc.)
│
├── tests/                         # Custom singular data quality tests
├── packages.yml                   # dbt-utils dependency
├── dbt_project.yml                # dbt project configuration
├── profiles.yml                   # BigQuery connection profile
└── business_interpretation.md     # Part 3 — Written business analysis
```

---

## How to Run

### Prerequisites

- Python with `dbt-bigquery` installed (`pip install dbt-bigquery`)
- A BigQuery project with a service account JSON key
- dbt version 1.11+

### 1. Set environment variables

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/your/gcp-key.json"
export DBT_BIGQUERY_DATASET="marts"   # default target dataset
export DBT_BIGQUERY_LOCATION="US"     # must match your BigQuery dataset region
```

### 2. Install dependencies

```bash
dbt deps
```

### 3. Verify connection

```bash
dbt debug
```

### 4. Run the full pipeline

```bash
dbt build
```

This will:
1. Load the three seed CSV files into `raw_data`
2. Build all staging views, intermediate views, and mart tables
3. Run all 29 data quality tests

---

## How the Models Work

### Data Flow

```
Seeds (raw_data)
    └── Staging (cleaned views)
            └── Intermediate (date spine, subscription expansion)
                    └── Marts (analytics tables)
                              └── Tableau Dashboard
```

### Layer-by-layer

| Layer | What it does |
|---|---|
| **Staging** | Casts data types, parses dates, normalises text (lowercase/uppercase). One model per source table. |
| **Intermediate** | `int_calendar_dates` generates a dynamic date spine bounded to the actual data range. `int_subscription_months` expands each subscription across every calendar month it was active. |
| **Marts — Facts** | `fct_subscriptions` computes monthly MRR, churn, and new subscriber flags. `fct_user_activity_monthly` tracks product engagement using a 30-day rolling event window. |
| **Marts — Aggregation** | `agg_subscription_kpis_monthly` joins all fact tables into a single row-per-month summary table that Tableau reads directly. |

---

## How the Dashboard Connects

The Tableau dashboard connects directly to the `marts` dataset in BigQuery.

The primary table powering all four dashboard charts is:

**`marts.agg_subscription_kpis_monthly`**

| Column | Dashboard Use |
|---|---|
| `month_start` | X-axis time dimension on all charts |
| `mrr` | Monthly Recurring Revenue (MRR) trend line |
| `active_subscribers` | Active Subscribers KPI card + plan distribution bar chart |
| `new_subscribers` | New Subscribers KPI card |
| `churn_rate` | Churn Rate KPI card + trend line |
| `usage_proxy_pct` | Product Engagement % trend line |

**Connection steps:**
1. Open Tableau Desktop → Connect to **Google BigQuery**
2. Select project `dishassignment`, dataset `marts`
3. Drag `agg_subscription_kpis_monthly` onto the canvas
4. Use `month_start` as the date dimension to filter and trend all metrics

---

## Data Quality

29 automated tests cover:
- `not_null` and `unique` constraints on all primary keys
- `accepted_values` for `plan_type` and `event_type` fields
- Custom singular tests for non-negative MRR and valid subscription date ranges

Run tests independently with:
```bash
dbt test
```
