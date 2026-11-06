-- =====================================================================
-- GEPER - Gestion de Personal y Puestos
-- 90_reset_lab.sql  -- RUN AS GEPER_OWNER (or GEPER_APP)
--
-- Restores the OBSERVATIONS column to its seeded baseline for every
-- employee. Run this after exercising SECURITY-LAB JAVA-XSS-01 to remove
-- any content entered during the exercise. It does NOT drop or recreate
-- any object and does NOT touch job/salary/history data.
-- =====================================================================

-- Clear all observations, then re-apply the four seeded notes.
UPDATE EMPLOYEES SET OBSERVATIONS = NULL;

UPDATE EMPLOYEES SET OBSERVATIONS = 'Fundadora del registro central.'       WHERE EMPLOYEE_ID = 101;
UPDATE EMPLOYEES SET OBSERVATIONS = 'Responsable de politicas de personal.' WHERE EMPLOYEE_ID = 103;
UPDATE EMPLOYEES SET OBSERVATIONS = 'Lleva la conciliacion mensual.'        WHERE EMPLOYEE_ID = 107;
UPDATE EMPLOYEES SET OBSERVATIONS = 'Apoyo financiero a RRHH.'              WHERE EMPLOYEE_ID = 110;
UPDATE EMPLOYEES SET OBSERVATIONS = 'Mantiene el nucleo del registro.'      WHERE EMPLOYEE_ID = 111;
UPDATE EMPLOYEES SET OBSERVATIONS = 'Mayor cartera de la sucursal.'         WHERE EMPLOYEE_ID = 117;
UPDATE EMPLOYEES SET OBSERVATIONS = 'Supervisa el turno diurno.'           WHERE EMPLOYEE_ID = 123;
UPDATE EMPLOYEES SET OBSERVATIONS = 'Enlace con la planta sur.'            WHERE EMPLOYEE_ID = 130;

COMMIT;
