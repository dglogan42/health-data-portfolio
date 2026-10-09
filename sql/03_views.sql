CREATE VIEW health.flagged_lab_results AS
SELECT l.*, a.patient_id,
       CASE WHEN result_value < reference_low THEN 'low'
            WHEN result_value > reference_high THEN 'high'
            WHEN reference_low IS NULL AND reference_high IS NULL THEN 'unclassified'
            ELSE 'within supplied bounds' END AS result_flag
FROM health.lab_results l JOIN health.appointments a USING (appointment_id);
