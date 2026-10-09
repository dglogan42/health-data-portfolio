BEGIN;
CREATE SCHEMA health;
CREATE TABLE health.patients (
  patient_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  patient_code text NOT NULL UNIQUE,
  date_of_birth date NOT NULL,
  city text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE health.clinicians (
  clinician_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  display_name text NOT NULL,
  specialty text NOT NULL
);
CREATE TABLE health.appointments (
  appointment_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  patient_id integer NOT NULL REFERENCES health.patients,
  clinician_id integer NOT NULL REFERENCES health.clinicians,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  status text NOT NULL CHECK (status IN ('scheduled','completed','cancelled','no_show')),
  reason text NOT NULL,
  CHECK (ends_at > starts_at)
);
CREATE TABLE health.diagnoses (
  diagnosis_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  appointment_id integer NOT NULL REFERENCES health.appointments,
  diagnosis_code text NOT NULL,
  description text NOT NULL,
  UNIQUE (appointment_id, diagnosis_code)
);
CREATE TABLE health.prescriptions (
  prescription_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  appointment_id integer NOT NULL REFERENCES health.appointments,
  medication_name text NOT NULL,
  instructions text NOT NULL,
  prescribed_on date NOT NULL,
  ends_on date,
  CHECK (ends_on IS NULL OR ends_on >= prescribed_on)
);
CREATE TABLE health.lab_results (
  lab_result_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  appointment_id integer NOT NULL REFERENCES health.appointments,
  test_name text NOT NULL,
  collected_at timestamptz NOT NULL,
  result_value numeric(12,3) NOT NULL,
  unit text NOT NULL,
  reference_low numeric(12,3),
  reference_high numeric(12,3),
  CHECK (reference_low IS NULL OR reference_high IS NULL OR reference_low <= reference_high)
);
CREATE INDEX appointments_patient_time_idx ON health.appointments(patient_id, starts_at DESC);
CREATE INDEX appointments_clinician_time_idx ON health.appointments(clinician_id, starts_at);
CREATE INDEX diagnoses_code_idx ON health.diagnoses(diagnosis_code);
CREATE INDEX prescriptions_appointment_idx ON health.prescriptions(appointment_id);
CREATE INDEX lab_results_appointment_time_idx ON health.lab_results(appointment_id, collected_at DESC);
COMMIT;
