DO $$
DECLARE t text; source_count bigint; raw_count bigint;
BEGIN
 FOREACH t IN ARRAY ARRAY['patients','clinicians','appointments','diagnoses','prescriptions','lab_results'] LOOP
   EXECUTE format('SELECT count(*) FROM health.%I',t) INTO source_count;
   EXECUTE format('SELECT count(*) FROM raw.%I',t) INTO raw_count;
   IF source_count <> raw_count THEN RAISE EXCEPTION 'Source reconciliation failed: %',t; END IF;
 END LOOP;
 IF (SELECT count(*) FROM marts.fct_appointments) <> (SELECT count(*) FROM raw.appointments)
 THEN RAISE EXCEPTION 'Appointment grain reconciliation failed'; END IF;
 IF EXISTS (SELECT 1 FROM staging.appointments WHERE status NOT IN ('scheduled','completed','cancelled','no_show') OR duration_minutes<=0)
 THEN RAISE EXCEPTION 'Invalid appointment status or duration'; END IF;
 IF EXISTS (SELECT 1 FROM staging.appointments a LEFT JOIN staging.patients p USING(patient_id)
 LEFT JOIN staging.clinicians c USING(clinician_id) WHERE p.patient_id IS NULL OR c.clinician_id IS NULL)
 THEN RAISE EXCEPTION 'Orphan appointment'; END IF;
 IF (SELECT coalesce(sum(diagnosis_count),0) FROM marts.fct_appointments) <> (SELECT count(*) FROM raw.diagnoses)
 OR (SELECT coalesce(sum(prescription_count),0) FROM marts.fct_appointments) <> (SELECT count(*) FROM raw.prescriptions)
 OR (SELECT coalesce(sum(lab_count),0) FROM marts.fct_appointments) <> (SELECT count(*) FROM raw.lab_results)
 THEN RAISE EXCEPTION 'Child record reconciliation failed'; END IF;
 IF (SELECT coalesce(sum(bookings),0) FROM marts.daily_activity) <> (SELECT count(*) FROM raw.appointments)
 THEN RAISE EXCEPTION 'Daily activity reconciliation failed'; END IF;
END $$;
