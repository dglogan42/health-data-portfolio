BEGIN;
INSERT INTO health.patients(patient_code,date_of_birth,city)
SELECT 'DEMO-' || lpad(n::text,4,'0'), DATE '1960-01-01' + ((n*137)%20000),
       (ARRAY['Auckland','Wellington','Christchurch','Hamilton'])[1+(n%4)]
FROM generate_series(1,100) AS s(n);
INSERT INTO health.clinicians(display_name,specialty)
SELECT 'Demo clinician ' || n, (ARRAY['General practice','Cardiology','Respiratory'])[1+(n%3)]
FROM generate_series(1,8) AS s(n);
INSERT INTO health.appointments(patient_id,clinician_id,starts_at,ends_at,status,reason)
SELECT 1+((n-1)%100),1+((n-1)%8),
       TIMESTAMPTZ '2026-01-01 09:00:00+13' + n*INTERVAL '1 hour',
       TIMESTAMPTZ '2026-01-01 09:00:00+13' + n*INTERVAL '1 hour' + INTERVAL '30 minutes',
       CASE WHEN n%10=0 THEN 'no_show' WHEN n%10=1 THEN 'cancelled' ELSE 'completed' END,
       'Synthetic review visit'
FROM generate_series(1,300) AS s(n);
INSERT INTO health.diagnoses(appointment_id,diagnosis_code,description)
SELECT appointment_id,'DEMO-' || (appointment_id%3),
       (ARRAY['Synthetic condition A','Synthetic condition B','Synthetic condition C'])[1+(appointment_id%3)]
FROM health.appointments WHERE status='completed';
INSERT INTO health.prescriptions(appointment_id,medication_name,instructions,prescribed_on,ends_on)
SELECT appointment_id,'DEMO medication ' || (appointment_id%4),
       'Placeholder only; no clinical dosing guidance',
       (starts_at AT TIME ZONE 'Pacific/Auckland')::date,
       (starts_at AT TIME ZONE 'Pacific/Auckland')::date+7
FROM health.appointments WHERE status='completed' AND appointment_id%2=0;
INSERT INTO health.lab_results(appointment_id,test_name,collected_at,result_value,unit,reference_low,reference_high)
SELECT appointment_id,'Synthetic marker',starts_at+INTERVAL '15 minutes',
       5+(appointment_id%12),'demo units',5,12
FROM health.appointments WHERE status='completed';
COMMIT;
