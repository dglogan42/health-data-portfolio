CREATE SCHEMA IF NOT EXISTS marts;
CREATE OR REPLACE VIEW marts.dim_patients AS SELECT * FROM staging.patients;
CREATE OR REPLACE VIEW marts.dim_clinicians AS SELECT * FROM staging.clinicians;
DROP TABLE IF EXISTS marts.fct_appointments CASCADE;
-- Aggregate each child separately to avoid multiplying rows when joining.
CREATE TABLE marts.fct_appointments AS
WITH d AS (SELECT appointment_id,count(*) AS diagnosis_count FROM staging.diagnoses GROUP BY 1),
 p AS (SELECT appointment_id,count(*) AS prescription_count FROM staging.prescriptions GROUP BY 1),
 l AS (SELECT appointment_id,count(*) AS lab_count,
       count(*) FILTER (WHERE result_flag IN ('low','high')) AS flagged_lab_count
       FROM staging.lab_results GROUP BY 1)
SELECT a.*,coalesce(d.diagnosis_count,0) AS diagnosis_count,
 coalesce(p.prescription_count,0) AS prescription_count,
 coalesce(l.lab_count,0) AS lab_count,coalesce(l.flagged_lab_count,0) AS flagged_lab_count
FROM staging.appointments a LEFT JOIN d USING(appointment_id)
LEFT JOIN p USING(appointment_id) LEFT JOIN l USING(appointment_id);
ALTER TABLE marts.fct_appointments ADD PRIMARY KEY(appointment_id);
CREATE INDEX fct_appointments_patient_date_idx ON marts.fct_appointments(patient_id,appointment_date);
CREATE OR REPLACE VIEW marts.daily_activity AS
SELECT appointment_date,count(*) AS bookings,
 count(*) FILTER (WHERE status='completed') AS completed,
 count(*) FILTER (WHERE status='cancelled') AS cancelled,
 count(*) FILTER (WHERE status='no_show') AS no_shows,
 round(100.0*count(*) FILTER (WHERE status='no_show')/nullif(count(*),0),2) AS no_show_pct,
 sum(flagged_lab_count) AS flagged_lab_results
FROM marts.fct_appointments GROUP BY 1;
CREATE OR REPLACE VIEW marts.patient_activity AS
SELECT p.patient_id,p.patient_code,p.city,count(a.appointment_id) AS bookings,
 count(a.appointment_id) FILTER (WHERE a.status='completed') AS completed,
 max(a.starts_at) FILTER (WHERE a.status='completed') AS latest_completed_visit
FROM marts.dim_patients p LEFT JOIN marts.fct_appointments a USING(patient_id)
GROUP BY p.patient_id,p.patient_code,p.city;
CREATE OR REPLACE VIEW marts.clinician_activity AS
SELECT c.clinician_id,c.display_name,c.specialty,count(a.appointment_id) AS bookings,
 count(a.appointment_id) FILTER (WHERE a.status='completed') AS completed
FROM marts.dim_clinicians c LEFT JOIN marts.fct_appointments a USING(clinician_id)
GROUP BY c.clinician_id,c.display_name,c.specialty;
