CREATE SCHEMA IF NOT EXISTS raw;
-- Snapshot replacement takes place within the pipeline transaction.
-- CASCADE removes this project's dependent views before rebuilding them.
DROP TABLE IF EXISTS raw.patients, raw.clinicians, raw.appointments,
  raw.diagnoses, raw.prescriptions, raw.lab_results CASCADE;
CREATE TABLE raw.patients AS SELECT *, current_timestamp AS extracted_at FROM health.patients;
CREATE TABLE raw.clinicians AS SELECT *, current_timestamp AS extracted_at FROM health.clinicians;
CREATE TABLE raw.appointments AS SELECT *, current_timestamp AS extracted_at FROM health.appointments;
CREATE TABLE raw.diagnoses AS SELECT *, current_timestamp AS extracted_at FROM health.diagnoses;
CREATE TABLE raw.prescriptions AS SELECT *, current_timestamp AS extracted_at FROM health.prescriptions;
CREATE TABLE raw.lab_results AS SELECT *, current_timestamp AS extracted_at FROM health.lab_results;
