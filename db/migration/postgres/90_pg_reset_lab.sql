-- =====================================================================
-- GEPER - Gestion de Personal y Puestos
-- 90_pg_reset_lab.sql  -- RUN AS geper_owner (or geper_app)
--
-- Restores the observations column to its seeded baseline for every
-- employee. Run this after exercising SECURITY-LAB JAVA-XSS-01 to remove
-- any content entered during the exercise. It does NOT drop or recreate
-- any object and does NOT touch job/salary/history data.
-- =====================================================================

-- Clear all observations, then re-apply the eight seeded notes.
UPDATE employees SET observations = NULL;

UPDATE employees SET observations = 'Fundadora del registro central.'       WHERE employee_id = 101;
UPDATE employees SET observations = 'Responsable de politicas de personal.' WHERE employee_id = 103;
UPDATE employees SET observations = 'Lleva la conciliacion mensual.'        WHERE employee_id = 107;
UPDATE employees SET observations = 'Apoyo financiero a RRHH.'              WHERE employee_id = 110;
UPDATE employees SET observations = 'Mantiene el nucleo del registro.'      WHERE employee_id = 111;
UPDATE employees SET observations = 'Mayor cartera de la sucursal.'         WHERE employee_id = 117;
UPDATE employees SET observations = 'Supervisa el turno diurno.'           WHERE employee_id = 123;
UPDATE employees SET observations = 'Enlace con la planta sur.'            WHERE employee_id = 130;
