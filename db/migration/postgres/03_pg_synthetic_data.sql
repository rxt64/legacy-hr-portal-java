-- =====================================================================
-- GEPER - Gestion de Personal y Puestos
-- 03_pg_synthetic_data.sql  -- RUN AS geper_owner
--
-- Deterministic synthetic data, converted from the Oracle baseline
-- (db/data/03_synthetic_data.sql / docs/functional-baseline.md). ALL names,
-- identifiers and figures are fictitious and bear no relation to any real
-- person or organization. Re-running is idempotent: it deletes existing
-- rows first, so counts and aggregates are reproducible for the functional
-- baseline.
--
-- NOTE on sequences: departments_seq (START WITH 70) and employees_seq
-- (START WITH 1000) already start past the highest seeded id below (60 and
-- 130 respectively), so no setval() adjustment is needed after loading this
-- data (unlike the Oracle version, which looped NEXTVAL calls defensively
-- to the same effect).
-- =====================================================================

DELETE FROM job_history;
DELETE FROM employees;
DELETE FROM jobs;
DELETE FROM departments;

-- ------------------------------------------------------------------
-- Departments
-- ------------------------------------------------------------------
INSERT INTO departments (department_id, department_name, location) VALUES (10, 'Direccion General', 'Monte Azul Central');
INSERT INTO departments (department_id, department_name, location) VALUES (20, 'Recursos Humanos',  'Monte Azul Central');
INSERT INTO departments (department_id, department_name, location) VALUES (30, 'Finanzas',          'Torre Norte');
INSERT INTO departments (department_id, department_name, location) VALUES (40, 'Tecnologia',        'Torre Norte');
INSERT INTO departments (department_id, department_name, location) VALUES (50, 'Ventas',            'Sucursal Valle');
INSERT INTO departments (department_id, department_name, location) VALUES (60, 'Operaciones',       'Planta Sur');

-- ------------------------------------------------------------------
-- Jobs (salary ranges)
-- ------------------------------------------------------------------
INSERT INTO jobs (job_id, job_title, min_salary, max_salary) VALUES ('DIR_GEN',  'Director General',        8000, 15000);
INSERT INTO jobs (job_id, job_title, min_salary, max_salary) VALUES ('GER_RRHH', 'Gerente de RRHH',         4500,  9000);
INSERT INTO jobs (job_id, job_title, min_salary, max_salary) VALUES ('ANAL_RH',  'Analista de RRHH',        1800,  3500);
INSERT INTO jobs (job_id, job_title, min_salary, max_salary) VALUES ('CONTAD',   'Contador',                2200,  4200);
INSERT INTO jobs (job_id, job_title, min_salary, max_salary) VALUES ('DESARR',   'Desarrollador',           2000,  4800);
INSERT INTO jobs (job_id, job_title, min_salary, max_salary) VALUES ('SOPORTE',  'Tecnico de Soporte',      1400,  2600);
INSERT INTO jobs (job_id, job_title, min_salary, max_salary) VALUES ('VENDE',    'Ejecutivo de Ventas',     1500,  3800);
INSERT INTO jobs (job_id, job_title, min_salary, max_salary) VALUES ('RECEP',    'Recepcionista',           1000,  1700);
INSERT INTO jobs (job_id, job_title, min_salary, max_salary) VALUES ('SUPERV',   'Supervisor de Planta',    2300,  4500);
INSERT INTO jobs (job_id, job_title, min_salary, max_salary) VALUES ('OPER',     'Operario',                1100,  2000);

-- ------------------------------------------------------------------
-- Employees (30 rows, deterministic). hire_date and assignment_start_date
-- set explicitly so the baseline does not drift with CURRENT_DATE.
-- ------------------------------------------------------------------
-- Direccion General (10)
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (101,'Marisol','Fonseca Arias','mfonseca@monteazul.example', DATE '2008-03-01','DIR_GEN', 13200,10, DATE '2008-03-01','Fundadora del registro central.');
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (102,'Ramiro','Quesada Mora','rquesada@monteazul.example',   DATE '2010-06-15','RECEP',    1550,10, DATE '2010-06-15',NULL);
-- Recursos Humanos (20)
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (103,'Beatriz','Navarro Leon','bnavarro@monteazul.example',  DATE '2009-02-10','GER_RRHH', 7800,20, DATE '2009-02-10','Responsable de politicas de personal.');
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (104,'Oscar','Valverde Rojas','ovalverde@monteazul.example', DATE '2012-09-03','ANAL_RH',  2900,20, DATE '2012-09-03',NULL);
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (105,'Tatiana','Herrera Solis','therrera@monteazul.example', DATE '2013-01-21','ANAL_RH',  2650,20, DATE '2013-01-21',NULL);
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (106,'Gerardo','Campos Vega','gcampos@monteazul.example',    DATE '2014-07-07','RECEP',    1480,20, DATE '2014-07-07',NULL);
-- Finanzas (30)
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (107,'Lucia','Montero Cruz','lmontero@monteazul.example',    DATE '2010-11-02','CONTAD',   3900,30, DATE '2010-11-02','Lleva la conciliacion mensual.');
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (108,'Esteban','Rodriguez Pena','erodriguez@monteazul.example',DATE '2011-04-18','CONTAD', 3600,30, DATE '2011-04-18',NULL);
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (109,'Daniela','Araya Mena','daraya@monteazul.example',      DATE '2015-08-12','CONTAD',   2450,30, DATE '2015-08-12',NULL);
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (110,'Hugo','Brenes Castro','hbrenes@monteazul.example',     DATE '2013-10-30','ANAL_RH',  3100,30, DATE '2013-10-30','Apoyo financiero a RRHH.');
-- Tecnologia (40)
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (111,'Veronica','Jimenez Soto','vjimenez@monteazul.example', DATE '2011-02-14','DESARR',   4600,40, DATE '2011-02-14','Mantiene el nucleo del registro.');
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (112,'Andres','Vargas Lobo','avargas@monteazul.example',     DATE '2012-05-09','DESARR',   4200,40, DATE '2012-05-09',NULL);
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (113,'Paola','Chaves Ureña','pchaves@monteazul.example',     DATE '2014-03-25','DESARR',   3400,40, DATE '2014-03-25',NULL);
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (114,'Mauricio','Segura Alfaro','msegura@monteazul.example', DATE '2013-06-11','SOPORTE',  2300,40, DATE '2013-06-11',NULL);
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (115,'Karla','Rojas Benavides','krojas@monteazul.example',   DATE '2016-01-19','SOPORTE',  1900,40, DATE '2016-01-19',NULL);
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (116,'Felipe','Mora Zuñiga','fmora@monteazul.example',       DATE '2015-11-05','SOPORTE',  2050,40, DATE '2015-11-05',NULL);
-- Ventas (50)
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (117,'Silvia','Delgado Ramirez','sdelgado@monteazul.example',DATE '2010-09-20','VENDE',    3700,50, DATE '2010-09-20','Mayor cartera de la sucursal.');
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (118,'Jorge','Aguilar Fonseca','jaguilar@monteazul.example', DATE '2012-12-01','VENDE',    3200,50, DATE '2012-12-01',NULL);
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (119,'Natalia','Cordero Vega','ncordero@monteazul.example',  DATE '2014-04-22','VENDE',    2800,50, DATE '2014-04-22',NULL);
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (120,'Diego','Ramirez Solano','dramirez@monteazul.example',  DATE '2015-02-16','VENDE',    2600,50, DATE '2015-02-16',NULL);
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (121,'Carolina','Soto Picado','csoto@monteazul.example',     DATE '2016-07-11','VENDE',    2400,50, DATE '2016-07-11',NULL);
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (122,'Rafael','Vega Montoya','rvega@monteazul.example',      DATE '2011-10-17','VENDE',    3350,50, DATE '2011-10-17',NULL);
-- Operaciones (60)
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (123,'Monica','Alvarado Rios','malvarado@monteazul.example', DATE '2009-05-04','SUPERV',   4300,60, DATE '2009-05-04','Supervisa el turno diurno.');
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (124,'Pablo','Garcia Loaiza','pgarcia@monteazul.example',    DATE '2011-08-29','SUPERV',   3900,60, DATE '2011-08-29',NULL);
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (125,'Adriana','Mendez Quiros','amendez@monteazul.example',  DATE '2013-03-07','OPER',     1750,60, DATE '2013-03-07',NULL);
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (126,'Luis','Castillo Umaña','lcastillo@monteazul.example',  DATE '2014-09-15','OPER',     1650,60, DATE '2014-09-15',NULL);
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (127,'Gabriela','Rivera Salas','grivera@monteazul.example',  DATE '2015-12-02','OPER',     1600,60, DATE '2015-12-02',NULL);
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (128,'Sergio','Ortiz Camacho','sortiz@monteazul.example',    DATE '2016-04-28','OPER',     1550,60, DATE '2016-04-28',NULL);
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (129,'Patricia','Nuñez Villalobos','pnunez@monteazul.example',DATE '2012-06-19','OPER',    1820,60, DATE '2012-06-19',NULL);
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES
 (130,'Alberto','Jara Esquivel','ajara@monteazul.example',    DATE '2010-01-25','SUPERV',   4100,60, DATE '2010-01-25','Enlace con la planta sur.');

-- ------------------------------------------------------------------
-- Seed employment history for a few employees (prior assignments).
-- Inserted directly; fn_update_job_history() fires only on UPDATE.
-- ------------------------------------------------------------------
INSERT INTO job_history (employee_id, start_date, end_date, job_id, department_id) VALUES (101, DATE '2008-03-01', DATE '2009-02-10', 'GER_RRHH', 20);
INSERT INTO job_history (employee_id, start_date, end_date, job_id, department_id) VALUES (103, DATE '2009-02-10', DATE '2012-09-03', 'ANAL_RH', 20);
INSERT INTO job_history (employee_id, start_date, end_date, job_id, department_id) VALUES (111, DATE '2011-02-14', DATE '2013-06-11', 'SOPORTE', 40);
INSERT INTO job_history (employee_id, start_date, end_date, job_id, department_id) VALUES (117, DATE '2010-09-20', DATE '2012-12-01', 'RECEP',   50);
