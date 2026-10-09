# Health Data Platform

SQL-first portfolio platform using PostgreSQL 16, Python orchestration, and Docker. Synthetic data only. The existing `health` schema remains the collection/source database. The pipeline snapshots six tables into `raw`, exposes cleaned `staging` views, and publishes appointment facts, dimensions, and activity marts.

## Upgrade your running database

Your supplied terminal log confirms healthy startup on port 5434, seed checks, six expected counts, and successful analytics queries. Extract this archive into a new directory beside `~/health-data`. Keep your current database volume and credentials:

```bash
cd ~/health-data-platform
cp ~/health-data/.env .env
sudo docker compose -p health-data up -d --wait db
sudo docker compose -p health-data run --build --rm pipeline
sudo docker compose -p health-data exec -T db sh -c \
  'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < queries/platform.sql
```

The explicit project name `health-data` reuses `health-data_health_data`, matching your log. Do not use `down -v` during upgrade. No source schema migrations or reseeding are required. Initialization scripts are ignored for the already initialized volume. Keep the same project name on all subsequent Compose commands.

## Fresh installation

```bash
cd health-data-platform
cp .env.example .env
# Choose a password and a free POSTGRES_PORT in .env.
sudo docker compose up -d --wait db
sudo docker compose run --build --rm pipeline
sudo docker compose exec -T db sh -c \
  'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < queries/platform.sql
```

Fresh installs use their own volume under project name `health-data-platform`. If the older project is running, choose a different host port, such as 5435. The pipeline connects to `db:5432` inside Docker regardless of host port.

## Architecture and grains

| Layer | Objects | Purpose |
|---|---|---|
| health | Six source tables | Collect synthetic service records |
| raw | Six snapshot tables with extracted_at | Consistent snapshot of the source |
| staging | Six views | Clean labels, local visit dates, derived durations and lab flags |
| marts | dim_patients, dim_clinicians | One row per patient/clinician |
| marts | fct_appointments | One row per appointment, with separately aggregated child counts |
| marts | daily_activity | One row per Auckland calendar date with activity |
| marts | patient_activity, clinician_activity | Service activity including zero-visit entities |
| ops | pipeline_runs | Run status, timing, row counts, error type |

PostgreSQL holds all layers in one database for an approachable local deployment. Python only orchestrates SQL; transformations stay in versioned model files. A repeatable-read transaction makes all source snapshots consistent, and a database advisory lock serializes pipeline runs. Model changes and quality checks commit together. Failure rolls back the refresh and logs the run as failed; abruptly terminated processes can leave a run marked running.

Raw snapshots and the appointment fact are replaced on every run. This deliberately stores the latest snapshot, not historical changes. Downstream views rebuild in the same transaction; custom views depending on raw/facts may be removed by CASCADE, so add consumer views as managed models. Schema changes in source tables require reviewed model changes. No incremental ingestion, scheduling, web UI, dbt, or external connectors are included in this version.

## Acceptance checks

Run the pipeline twice. Both runs should succeed without changing business counts. With the original seed, expect:

| Source | Rows |
|---|---:|
| patients | 100 |
| clinicians | 8 |
| appointments | 300 |
| diagnoses | 240 |
| prescriptions | 120 |
| lab_results | 240 |

The fact totals should be 300 appointments, 240 diagnoses, 120 prescriptions, 240 labs, and 80 flagged demo labs. Quality checks reconcile source/raw counts, appointment grain, foreign references, statuses/durations, child aggregates, and daily totals. These checks follow current source counts and continue to work after you collect more records.

To check persistence with the existing project:

```bash
sudo docker compose -p health-data down
sudo docker compose -p health-data up -d --wait db
sudo docker compose -p health-data exec -T db sh -c \
  'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < queries/platform.sql
```

## Data and verification limits

All conditions, medications, lab units and bounds are synthetic placeholders. Seed visits fall within January 2026; deterministic seed arithmetic also means some patients have only cancelled/no-show visits. These patterns are useful for edge cases but are not representative health statistics.

AI assisted the SQL, Python and documentation. Source database runtime verification is evidenced by your attached log. The new platform's SQL syntax and Python compilation were checked locally. New platform end-to-end execution, Docker image build, Compose startup, and upgrade on your machine remain pending: Docker is unavailable here, and system permissions blocked installation of a temporary PostgreSQL instance. This demo does not implement clinical access controls or production operational procedures.
