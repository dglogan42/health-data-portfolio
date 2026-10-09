"""Atomic full-refresh snapshot pipeline; connection uses standard PG* variables."""
from pathlib import Path
import json
import sys
import time
import psycopg2
from psycopg2.extras import Json

MODELS = Path(__file__).resolve().parent.parent / 'models'
TABLES = ('patients', 'clinicians', 'appointments', 'diagnoses', 'prescriptions', 'lab_results')

def main():
    started = time.monotonic()
    with psycopg2.connect('') as audit:
        with audit.cursor() as cur:
            # Lock before initialization so concurrent startup also serializes.
            cur.execute('SELECT pg_advisory_lock(8264109)')
            cur.execute('CREATE SCHEMA IF NOT EXISTS ops')
            cur.execute('''CREATE TABLE IF NOT EXISTS ops.pipeline_runs (
              run_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
              started_at timestamptz NOT NULL DEFAULT now(),
              finished_at timestamptz, status text NOT NULL,
              row_counts jsonb, duration_seconds numeric, error_type text)''')
            cur.execute("INSERT INTO ops.pipeline_runs(status) VALUES ('running') RETURNING run_id")
            run_id = cur.fetchone()[0]
        audit.commit()
        try:
            with psycopg2.connect('') as conn:
                conn.set_session(isolation_level='REPEATABLE READ')
                with conn.cursor() as cur:
                    cur.execute("SET LOCAL lock_timeout = '30s'")
                    cur.execute("SET LOCAL statement_timeout = '120s'")
                    for model in sorted(MODELS.glob('*.sql')):
                        print(f'Running {model.name}', flush=True)
                        cur.execute(model.read_text())
                    counts = {}
                    for table in TABLES:
                        cur.execute(f'SELECT count(*) FROM raw.{table}')
                        counts[table] = cur.fetchone()[0]
                    cur.execute('ANALYZE marts.fct_appointments')
                    # Success metadata commits with the data, not after it.
                    cur.execute('''UPDATE ops.pipeline_runs SET status='succeeded',finished_at=now(),
                      row_counts=%s,duration_seconds=%s WHERE run_id=%s''',
                      (Json(counts), time.monotonic()-started, run_id))
            print(json.dumps({'run_id': run_id, 'status': 'succeeded', 'row_counts': counts}), flush=True)
        except Exception as exc:
            with audit.cursor() as cur:
                cur.execute('''UPDATE ops.pipeline_runs SET status='failed',finished_at=now(),
                  duration_seconds=%s,error_type=%s WHERE run_id=%s''',
                  (time.monotonic()-started, type(exc).__name__, run_id))
            audit.commit()
            print(f'Pipeline run {run_id} failed ({type(exc).__name__}); previous published data retained.', file=sys.stderr)
            raise
        finally:
            with audit.cursor() as cur:
                cur.execute('SELECT pg_advisory_unlock(8264109)')
            audit.commit()

if __name__ == '__main__':
    main()
