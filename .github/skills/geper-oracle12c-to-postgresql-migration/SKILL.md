---
name: geper-oracle12c-to-postgresql-migration
description: Migrate Oracle Database 12c R2 schema, sequences, PL/SQL trigger UPDATE_JOB_HISTORY, and JDBC queries (NVL, DUAL, NEXTVAL, SYSDATE) to Azure Database for PostgreSQL Flexible Server with PL/pgSQL trigger and offline data transfer
---

# GEPER Database Migration Skill: Oracle 12c R2 to Azure Database for PostgreSQL

## Overview

Guides the database schema conversion, PL/SQL-to-PL/pgSQL trigger migration, SQL dialect adaptation, and offline data transfer of **GEPER** from **Oracle Database 12c Release 2 (`12.2.0.1.0`)** to **Azure Database for PostgreSQL Flexible Server** (PostgreSQL 16).

## Steps

1. **Convert Schema and Types (`db/migration/postgres/01_pg_schema_and_roles.sql`)**:
   - Map `NUMBER(6)` -> `INTEGER`, `NUMBER(9,2)` -> `NUMERIC(9,2)`, `VARCHAR2(n)` -> `VARCHAR(n)`, `DATE` -> `DATE` (`CURRENT_DATE` default instead of `SYSDATE`).
   - Create schema `geper_owner` and least-privilege roles `geper_owner`, `geper_app`, and `geper_labro`.
   - Convert sequences `DEPARTMENTS_SEQ` (`START WITH 70 INCREMENT BY 10`) and `EMPLOYEES_SEQ` (`START WITH 1000 INCREMENT BY 1`).

2. **Convert PL/SQL Trigger `UPDATE_JOB_HISTORY` to PL/pgSQL (`SECURITY DEFINER`)**:
   - Implement `geper_owner.fn_update_job_history() RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER` so `geper_app` does not need direct `INSERT` privileges on `JOB_HISTORY` (preserving the exact definer-rights least-privilege boundary from Oracle).
   - Fire `BEFORE UPDATE OF job_id, department_id ON employees FOR EACH ROW WHEN (COALESCE(OLD.job_id, '~') <> COALESCE(NEW.job_id, '~') OR COALESCE(OLD.department_id, -1) <> COALESCE(NEW.department_id, -1))`.
   - Insert prior assignment into `job_history` with `end_date = CURRENT_DATE` and advance `NEW.assignment_start_date := CURRENT_DATE`.

3. **Adapt Oracle-Specific SQL in Spring JDBC Repositories**:
   - `DashboardRepository.java` & `DepartmentRepository.java`: Replace `NVL(x, 0)` with ANSI-standard `COALESCE(x, 0)` (compatible with both Oracle and PostgreSQL!).
   - `DepartmentRepository.java` & `EmployeeRepository.java`: Replace `SELECT DEPARTMENTS_SEQ.NEXTVAL FROM DUAL` / `SELECT EMPLOYEES_SEQ.NEXTVAL FROM DUAL` with `SELECT nextval('departments_seq')` / `SELECT nextval('employees_seq')`.
   - `application.yml`: Replace `ALTER SESSION SET CURRENT_SCHEMA = GEPER_OWNER` with `SET search_path TO geper_owner, public`.

## Sample Code

### PL/pgSQL Equivalent of `UPDATE_JOB_HISTORY`

```sql
CREATE OR REPLACE FUNCTION geper_owner.fn_update_job_history()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = geper_owner, public
AS $$
BEGIN
  INSERT INTO job_history (employee_id, start_date, end_date, job_id, department_id)
  VALUES (OLD.employee_id, OLD.assignment_start_date, CURRENT_DATE, OLD.job_id, OLD.department_id);

  NEW.assignment_start_date := CURRENT_DATE;
  RETURN NEW;
END;
$$;

CREATE TRIGGER update_job_history
  BEFORE UPDATE OF job_id, department_id ON geper_owner.employees
  FOR EACH ROW
  WHEN (
    COALESCE(OLD.job_id, '~') <> COALESCE(NEW.job_id, '~')
    OR COALESCE(OLD.department_id, -1) <> COALESCE(NEW.department_id, -1)
  )
  EXECUTE FUNCTION geper_owner.fn_update_job_history();
```

## Verification Checks

- Updating `JOB_ID` or `DEPARTMENT_ID` on an employee inserts exactly 1 row into `job_history` with the prior `job_id`/`department_id` and advances `assignment_start_date` to `CURRENT_DATE`.
- Updating `SALARY` only does NOT insert into `job_history`.
- Rolling back a transaction that changed `JOB_ID` rolls back the `job_history` row as well.
