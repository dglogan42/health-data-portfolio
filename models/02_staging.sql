CREATE SCHEMA IF NOT EXISTS staging;
CREATE OR REPLACE VIEW staging.patients AS
SELECT patient_id,patient_code,date_of_birth,trim(city) AS city FROM raw.patients;
CREATE OR REPLACE VIEW staging.clinicians AS
SELECT clinician_id,trim(display_name) AS display_name,trim(specialty) AS specialty FROM raw.clinicians;
CREATE OR REPLACE VIEW staging.appointments AS
SELECT appointment_id,patient_id,clinician_id,starts_at,ends_at,
       (starts_at AT TIME ZONE 'Pacific/Auckland')::date AS appointment_date,
       lower(trim(status)) AS status,reason,
       extract(epoch FROM ends_at-starts_at)/60 AS duration_minutes
FROM raw.appointments;
CREATE OR REPLACE VIEW staging.diagnoses AS SELECT diagnosis_id,appointment_id,diagnosis_code,description FROM raw.diagnoses;
CREATE OR REPLACE VIEW staging.prescriptions AS SELECT prescription_id,appointment_id,medication_name,instructions,prescribed_on,ends_on FROM raw.prescriptions;
CREATE OR REPLACE VIEW staging.lab_results AS
SELECT lab_result_id,appointment_id,test_name,collected_at,result_value,unit,reference_low,reference_high,
 CASE WHEN result_value < reference_low THEN 'low'
      WHEN result_value > reference_high THEN 'high'
      WHEN reference_low IS NULL OR reference_high IS NULL THEN 'unclassified'
      ELSE 'within supplied bounds' END AS result_flag
FROM raw.lab_results;
