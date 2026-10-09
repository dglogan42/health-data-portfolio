SELECT * FROM ops.pipeline_runs ORDER BY run_id DESC LIMIT 10;
SELECT count(*) AS appointments,sum(diagnosis_count) AS diagnoses,
 sum(prescription_count) AS prescriptions,sum(lab_count) AS labs,
 sum(flagged_lab_count) AS flagged_labs FROM marts.fct_appointments;
SELECT * FROM marts.daily_activity ORDER BY appointment_date;
SELECT * FROM marts.clinician_activity ORDER BY completed DESC,clinician_id;
-- Date spine ensures rolling windows mean seven calendar days, including zero-booking days.
WITH spine AS (
 SELECT generate_series(min(appointment_date)::timestamp,max(appointment_date)::timestamp,interval '1 day')::date AS day
 FROM marts.daily_activity
), daily AS (
 SELECT s.day,coalesce(d.bookings,0) AS bookings FROM spine s
 LEFT JOIN marts.daily_activity d ON d.appointment_date=s.day
)
SELECT day,bookings,sum(bookings) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS bookings_last_7_days
FROM daily ORDER BY day;
