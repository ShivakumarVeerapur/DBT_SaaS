# 📊 SaaS Subscription & Usage Analytics (dbt + BigQuery)

A complete, production-grade analytics engineering foundation built with **dbt Core** and **GCP BigQuery**. This project transforms raw, messy SaaS database dumps into clean, tested, and reliable business dimensions and facts to power C-suite dashboards in **Tableau**.

---

## 📖 The Story: What Problem Are We Solving?

Imagine you work at a subscription-based SaaS company. The Finance, Growth, and Product teams all need to know key business metrics: **Monthly Recurring Revenue (MRR)**, **active subscriber counts**, **churn rates**, and **user engagement**. 

Currently, the company suffers from:
* **Inconsistent Definitions:** Finance calculates MRR one way; Growth calculates it another.
* **Messy Raw Data:** Date fields are formatted differently, and active subscriptions have empty strings instead of proper `NULL` values.
* **Dashboard Chaos:** Two different Tableau dashboards show conflicting churn rates.

### The Solution: A Single Source of Truth
This repository implements a **structured data warehouse pipeline** using dbt. It takes raw database exports, cleans them, applies standardized business rules, tests them for data quality, and outputs a single, trusted table that powers all dashboards.

---

## 🏗️ Data Architecture (The DAG)

dbt compiles your SQL files and automatically determines the order in which tables must build based on their dependencies (represented as a **Directed Acyclic Graph** or **DAG**):

```mermaid
graph TD
    %% BigQuery Raw Tables (source)
    subgraph Raw [1. BigQuery Raw Tables - External Source]
        R_Users["🗄️ raw_data.Users<br/>(loaded by ingestion tool)"]
        R_Subs["🗄️ raw_data.Subscriptions<br/>(loaded by ingestion tool)"]
        R_Events["🗄️ raw_data.event<br/>(loaded by ingestion tool)"]
    end

    %% Staging Views
    subgraph Staging [2. Staging Layer - source() → Clean & Cast]
        stg_U["stg_users<br/>(view: dates parsed, strings trimmed)"]
        stg_S["stg_subscriptions<br/>(view: empty ends to NULL, types cast)"]
        stg_E["stg_events<br/>(view: parsed timestamps)"]
    end

    %% Snapshots
    subgraph Snaps [3. Snapshots - SCD Type 2 History]
        snp_U["snp_users<br/>(check: plan_type, country)"]
        snp_S["snp_subscriptions<br/>(check: monthly_price, end_date)"]
        snp_UT["snp_users_timestamp<br/>(timestamp: updated_at)"]
    end

    %% Intermediate Tables
    subgraph Intermediate [4. Intermediate Layer - Business Components]
        int_Cal["int_calendar_dates<br/>(ephemeral: date spine CTE, no BQ object)"]
        int_Subs["int_subscription_months<br/>(incremental table: expands snapshot history per month)"]
    end

    %% Marts Tables
    subgraph Marts [5. Marts Layer - Dimensional Modeling]
        dim_U["dim_users<br/>(table: clean user dimension)"]
        dim_D["dim_dates<br/>(table: date dimension with calendar flags)"]
        fct_S["fct_subscriptions<br/>(incremental table: MRR, status & churn with full price history)"]
        fct_UA["fct_user_activity_monthly<br/>(table: 30-day rolling engagement flags)"]
        agg_KPI["agg_subscription_kpis_monthly<br/>(table: dashboard rollup of all metrics)"]
    end

    %% BI Layer
    subgraph BI [6. Business Intelligence]
        Tableau["📊 Tableau Dashboard<br/>(MRR, Churn, Active Subs, Engagement)"]
    end

    %% Connections
    R_Users -->|source()| stg_U
    R_Subs -->|source()| stg_S
    R_Events -->|source()| stg_E

    stg_U --> snp_U
    stg_U --> snp_UT
    stg_S --> snp_S

    stg_U --> int_Cal
    stg_S --> int_Cal
    snp_S -->|ref()| int_Subs
    int_Cal -.->|ephemeral CTE| int_Subs

    stg_U --> dim_U
    int_Cal -.->|ephemeral CTE| dim_D
    int_Subs --> fct_S
    stg_E --> fct_UA
    fct_S --> fct_UA
    fct_S --> agg_KPI
    fct_UA --> agg_KPI

    agg_KPI --> Tableau

    %% Styling
    style Raw fill:#fdd,stroke:#333,stroke-width:2px
    style Staging fill:#eef,stroke:#333,stroke-width:2px
    style Snaps fill:#ffd,stroke:#333,stroke-width:2px
    style Intermediate fill:#fee,stroke:#333,stroke-width:2px
    style Marts fill:#efe,stroke:#333,stroke-width:2px
    style BI fill:#eff,stroke:#333,stroke-width:2px
```

---

## 📂 Understanding the Data Layers (For Beginners)

To keep the pipeline clean and maintainable, we separate our models into distinct directory layers:

| Layer | Analogy | Rules in dbt | Examples in this Project |
| :--- | :--- | :--- | :--- |
| **1. Raw Tables** | **Raw Ingredients:** External BigQuery tables populated by an ingestion tool (Fivetran, Airbyte, or `dbt seed`). | Referenced via `source()`, never `ref()`. | `raw_data.Users`, `raw_data.Subscriptions`, `raw_data.event` |
| **2. Staging** | **Washing & Cutting:** Cleaning fields, casting data types, and trimming whitespace. | 1:1 with raw tables. Materialized as **Views** to save cost. Never join or aggregate here. | [stg_users.sql](file:///e:/Data_Engg_Projects/DBT/dish_assignment/dish_assignment/models/staging/stg_users.sql), [stg_subscriptions.sql](file:///e:/Data_Engg_Projects/DBT/dish_assignment/dish_assignment/models/staging/stg_subscriptions.sql) |
| **3. Snapshots** | **The Time Machine:** Captures every version of a row that ever existed with `dbt_valid_from` / `dbt_valid_to` timestamps. | Run with `dbt snapshot` before `dbt run`. Downstream models read from snapshots, not staging. | [snp_users.sql](file:///e:/Data_Engg_Projects/DBT/dish_assignment/dish_assignment/snapshots/snp_users.sql), [snp_subscriptions.sql](file:///e:/Data_Engg_Projects/DBT/dish_assignment/dish_assignment/snapshots/snp_subscriptions.sql) |
| **4. Intermediate** | **Pre-cooking Components:** Complex reusable logic built on top of full historical data. | Never queried by BI tools directly. Materialized as **Tables** (expensive cross-joins cached). Helper-only models use **Ephemeral** (no BQ object). | [int_subscription_months.sql](file:///e:/Data_Engg_Projects/DBT/dish_assignment/dish_assignment/models/intermediate/int_subscription_months.sql), [int_calendar_dates.sql](file:///e:/Data_Engg_Projects/DBT/dish_assignment/dish_assignment/models/intermediate/int_calendar_dates.sql) |
| **5. Marts** | **The Finished Dish:** Standardized dimensions (`dim_`) and facts (`fct_`) ready for consumption. | Materialized as **Incremental Tables** in BigQuery — only new rows are merged on each run. | [fct_subscriptions.sql](file:///e:/Data_Engg_Projects/DBT/dish_assignment/dish_assignment/models/marts/fct_subscriptions.sql), [agg_subscription_kpis_monthly.sql](file:///e:/Data_Engg_Projects/DBT/dish_assignment/dish_assignment/models/marts/agg_subscription_kpis_monthly.sql) |


---

## 🔍 End-to-End Walkthrough: Tracing a Single User

Let's follow a single user, **User 2**, step-by-step through every layer of our pipeline to see exactly how the SQL transforms their messy data.

### 1. Raw Data Layer (BigQuery Tables)
User 2's data lives in `raw_data.*` BigQuery tables, loaded by the ingestion pipeline. Their history is fragmented:
* **Users table:** signed up on `07.01.23` (European format), lives in `US`, on plan `basic`.
* **Subscriptions table:** Has two separate subscription lifecycles:
  1. Sub `1001` starts `07.01.23` and ends `31.03.23` (ended/churned).
  2. Sub `1018` starts `01.04.23` and has no end date (still active — empty string in raw, `NULL` after staging).
* **Events table:** Contains multiple user actions (e.g. login `08.01.23 10:15`).

---

### 2. Staging Layer (Clean & Standardize)
`stg_` models use `source('raw', ...)` to read directly from BigQuery raw tables and clean User 2's rows into standardized database records:
* **`stg_users`** casts `user_id` to integer and parses the signup date format:
  ```
  user_id: 2 | signup_date: 2023-01-07 | country: "US" | plan_type: "basic"
  ```
* **`stg_subscriptions`** normalizes the empty end_date for Sub 1018:
  ```
  sub_id: 1001 | user_id: 2 | start_date: 2023-01-07 | end_date: 2023-03-31 | monthly_price: 20
  sub_id: 1018 | user_id: 2 | start_date: 2023-04-01 | end_date: NULL       | monthly_price: 20
  ```

---

### 2b. Snapshot Layer (Capture History)
`dbt snapshot` runs **before** `dbt run`. It reads from `stg_subscriptions`, hashes the `check_cols` (`monthly_price`, `end_date`), and writes history rows to `snp_subscriptions`:
  ```
  sub_id: 1001 | monthly_price: 20 | dbt_valid_from: 2026-05-27 | dbt_valid_to: NULL
  ```
If the price later changes from €20 to €30, the snapshot closes the old row and inserts a new one:
  ```
  sub_id: 1001 | monthly_price: 20 | dbt_valid_from: 2026-05-27 | dbt_valid_to: 2026-06-07
  sub_id: 1001 | monthly_price: 30 | dbt_valid_from: 2026-06-07 | dbt_valid_to: NULL
  ```
This means the intermediate layer always has the **full, accurate price history** — not just today's state.

---

### 3. Intermediate Layer (Expand & Align on Full History)
**`int_subscription_months`** reads from `snp_subscriptions` (not `stg_subscriptions`), so it works on the **full price history**, not just today's values. It cross-joins each snapshot version against the calendar months it was active for:
* **Sub 1001** (€20, valid Jan–Mar) expands into 3 monthly rows:
  * `sub_id: 1001 | month: 2023-01-01 | monthly_price: 20 | dbt_valid_from: <snapshot_ts>`
  * `sub_id: 1001 | month: 2023-02-01 | monthly_price: 20 | dbt_valid_from: <snapshot_ts>`
  * `sub_id: 1001 | month: 2023-03-01 | monthly_price: 20 | dbt_valid_from: <snapshot_ts>`
* **Sub 1018** (€20, active from Apr) expands into monthly rows for Apr, May, Jun...

The `int_calendar_dates` helper (ephemeral — no BigQuery object) generates the date spine and is inlined as a CTE at compile time. On incremental runs, only snapshot rows with a `dbt_valid_from` newer than the table's current max are processed — not the full history.

---

### 4. Marts Layer (Compute Business KPIs)
The final marts calculate specific flags and values for the business:
* **`fct_subscriptions`** looks at the start/end months and assigns subscription statuses:
  * **Jan 2023:** Status is **`new`** (first month of Sub 1001). MRR is **`€20`**.
  * **Feb 2023:** Status is **`active`** (continuing subscription). MRR is **`€20`**.
  * **Mar 2023:** Status is **`churned`** (Sub 1001 ended this month). MRR is **`€20`**.
  * **Apr 2023:** Status is **`new`** (first month of new Sub 1018). MRR is **`€20`**.
  * **May 2023:** Status is **`active`** (continuing Sub 1018). MRR is **`€20`**.
* **`fct_user_activity_monthly`** joins events to flag whether User 2 was active. Since they logged in during January but had zero events in May, they are flagged:
  * **Jan 2023:** `has_event_last_30d_flag = 1`
  * **May 2023:** `has_event_last_30d_flag = 0` (this flags User 2 as a "zombie" paying user).
* **`agg_subscription_kpis_monthly`** aggregates all users. User 2 contributes:
  * `+€20` to MRR in Jan, Feb, Mar, Apr, May.
  * `+1` new subscriber in Jan and Apr.
  * `+1` churned subscriber in March.

This structured transformation creates a direct, auditable path from raw files to the Tableau dashboard!

---

## ⚡ Advanced Implementations


This project implements industry-standard data warehouse patterns:

### 1. All 5 dbt Materialization Types (Used in This Project)

| Type | BigQuery Object | Used in | Why |
|---|---|---|---|
| `view` | BigQuery View — no data stored | Staging | Always fresh, zero storage cost |
| `table` | Full rebuild every `dbt run` | Intermediate | Expensive cross-join computed once, read cheaply by many downstream models |
| `incremental` | MERGE into existing table — only new rows | `int_subscription_months`, `fct_subscriptions` | Growing historical data — only process what's new |
| `ephemeral` | No BigQuery object — inlined as a CTE | `int_calendar_dates` | Pure helper used in one place; no storage cost, no extra query hop |
| `snapshot` | SCD Type 2 table with history timestamps | `snp_*` | Source rows get overwritten — snapshot preserves every version |

### 2. Incremental Models — Combined with Snapshot History
Both `int_subscription_months` and `fct_subscriptions` are incremental. They use `dbt_valid_from` (not `month_start`) as their incremental filter:
```sql
{% if is_incremental() %}
  where dbt_valid_from > (select max(dbt_valid_from) from {{ this }})
{% endif %}
```
* **Why `dbt_valid_from` not `month_start`?** A price change on subscription 1007 creates a new snapshot row for **February 2023** — a month already in the table. `month_start` filter would skip it entirely. `dbt_valid_from` catches it because it's a new snapshot version, regardless of which calendar month it covers.
* **Unique key:** `['subscription_id', 'month_start', 'dbt_valid_from']` — one row per subscription × month × price version.

### 3. History Tracking Snapshots (SCD Type 2)
When a raw BigQuery record is overwritten (e.g. price change, churn), the snapshot detects the difference and records both versions with timestamps:

| Snapshot | Strategy | Tracks |
|---|---|---|
| [snp_users.sql](file:///e:/Data_Engg_Projects/DBT/dish_assignment/dish_assignment/snapshots/snp_users.sql) | `check` | `plan_type`, `country` |
| [snp_subscriptions.sql](file:///e:/Data_Engg_Projects/DBT/dish_assignment/dish_assignment/snapshots/snp_subscriptions.sql) | `check` | `monthly_price`, `end_date` |
| [snp_users_timestamps.sql](file:///e:/Data_Engg_Projects/DBT/dish_assignment/dish_assignment/snapshots/snp_users_timestamps.sql) | `timestamp` | `updated_at` (cast from `signup_date`) |

After a price change on subscription 1007 from €50 → €65, `snp_subscriptions` contains:
```
+-----------------+---------------+---------------------+---------------------+
| subscription_id | monthly_price |   dbt_valid_from    |    dbt_valid_to     |
+-----------------+---------------+---------------------+---------------------+
|            1007 |            50 | 2026-06-01 19:45:xx | 2026-06-07 20:07:xx |
|            1007 |            65 | 2026-06-07 20:07:xx |                NULL |
+-----------------+---------------+---------------------+---------------------+
```
`int_subscription_months` reads both rows and expands them into **historically accurate** monthly MRR records — €50/month before the change, €65/month after.

### 3. Automated Data Quality Testing
We run **29 tests** on every deployment to ensure data integrity:
* **Unique & Not Null:** Applied to all primary keys (`user_id`, `subscription_id`, `event_id`).
* **Accepted Values:** Verifies `plan_type` contains only `free`, `basic`, or `pro`.
* **Custom Singular Tests:**
  * [assert_monthly_revenue_non_negative.sql](file:///e:/Data_Engg_Projects/DBT/dish_assignment/dish_assignment/tests/assert_monthly_revenue_non_negative.sql): Fails if monthly subscription price is less than 0.
  * [assert_subscription_dates_valid.sql](file:///e:/Data_Engg_Projects/DBT/dish_assignment/dish_assignment/tests/assert_subscription_dates_valid.sql): Fails if `end_date` is earlier than `start_date`.

---

## 🚀 How to Run the Project Locally

### 1. Prerequisites
* Python installed on your computer.
* A GCP BigQuery project with a Service Account JSON key.

### 2. Setup Virtual Environment & Install dbt
```bash
# Create python virtual environment
python -m venv .venv

# Activate it (Windows)
.venv\Scripts\activate

# Install dbt-bigquery adapter
pip install dbt-bigquery
```

### 3. Install Packages
Downloads utility packages like `dbt-utils` declared in `packages.yml`:
```bash
dbt deps
```

### 4. Configure Connection
Create a [profiles.yml](file:///e:/Data_Engg_Projects/DBT/dish_assignment/dish_assignment/profiles.yml) in your project root pointing to your BigQuery key:
```yaml
dish_assignment:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: service-account
      project: fx-project-shiva-26
      dataset: marts
      location: europe-west3
      threads: 4
      keyfile: E:\Data_Engg_Projects\Keys\fx-project-shiva-26-406b116a0688.json
```

Verify the connection:
```bash
dbt debug
```

---

## 🛠️ Essential dbt Commands

Execute these commands from your project root folder:

```bash
# --- Initial setup (one-time) ---

# Load seed CSVs into BigQuery as raw_data.* tables
dbt seed

# --- Production run order (every scheduled run) ---

# STEP 1: Always run snapshots FIRST — they must be populated
# before intermediate models read from them
dbt snapshot

# STEP 2: Run all models incrementally (only new rows processed)
dbt run

# STEP 3: Run data quality tests
dbt test

# --- Useful shortcuts ---

# Full clean rebuild (drops and recreates all incremental tables)
dbt run --full-refresh

# Run a single model and all its upstream dependencies
dbt run --select +int_subscription_months

# Generate and serve interactive documentation site
dbt docs generate
dbt docs serve
```

> [!IMPORTANT]
> **Always run `dbt snapshot` before `dbt run`.** The intermediate model `int_subscription_months` reads from `snp_subscriptions`. If you run models before snapshots, the intermediate will process stale snapshot data and miss any changes that happened in the raw tables since the last run.

---

## 📊 Tableau Dashboard Connection

The Tableau dashboard connects directly to the BigQuery project.

Instead of writing complex SQL queries in Tableau (which slows down dashboards), Tableau points directly to:
👉 **`marts.agg_subscription_kpis_monthly`**

This table has pre-calculated monthly metrics:
* `month_start` (X-axis for timelines)
* `mrr` (Monthly Recurring Revenue trend line)
* `active_subscribers` (Total paying customer cards)
* `churn_rate` (Customer loss trend lines)
* `usage_proxy_pct` (Activity trend: percentage of active users who logged in or used features in the last 30 days)
