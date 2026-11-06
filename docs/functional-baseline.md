# Línea base funcional — GEPER

Valores verificables tras provisionar el esquema y cargar
`db/data/03_synthetic_data.sql`. Sirven como referencia para comprobar que una
migración o modernización **preserva el comportamiento**. Verificado el
2026-11-06 contra **Oracle Database 12c Enterprise Edition Release 12.2.0.1.0**
(PDB `GEPERPDB` sobre Oracle Linux Server 7.4 en Azure `mexicocentral`, con
Java 8 `1.8.0_432` y `ojdbc8` `12.2.0.1`).

## Conteos

| Entidad | Valor |
|---------|-------|
| Empleados | **30** |
| Departamentos | **6** |
| Puestos | **10** |
| Filas de historial sembradas | **4** |

```sql
SELECT COUNT(*) FROM EMPLOYEES;    -- 30
SELECT COUNT(*) FROM DEPARTMENTS;  -- 6
SELECT COUNT(*) FROM JOBS;         -- 10
SELECT COUNT(*) FROM JOB_HISTORY;  -- 4
```

## Agregados monetarios

| Indicador | Valor |
|-----------|-------|
| Suma salarial total | **99800** |
| Salario promedio | **3326.67** (≈) |

```sql
SELECT SUM(SALARY) FROM EMPLOYEES;             -- 99800
SELECT ROUND(AVG(SALARY),2) FROM EMPLOYEES;    -- 3326.67
```

### Resumen salarial por departamento (orden por suma desc.)

El tablero y `/departamentos` deben reproducir estos totales (calculados en
Oracle; nunca hardcodeados):

| Depto | Nombre | Empleados | Suma salarial |
|-------|--------|-----------|---------------|
| 60 | Operaciones | 8 | 20670 |
| 40 | Tecnología | 6 | 18450 |
| 50 | Ventas | 6 | 18050 |
| 20 | Recursos Humanos | 4 | 14830 |
| 10 | Dirección General | 2 | 14750 |
| 30 | Finanzas | 4 | 13050 |
| | **Total** | **30** | **99800** |

> Los 30 empleados tienen departamento asignado. Los totales se recalculan en
> vivo con la consulta de `DepartmentRepository.salarySummary` (agregación en
> Oracle, nunca hardcodeados).

## Relaciones comprobables

- Todo `EMPLOYEES.JOB_ID` existe en `JOBS` (FK).
- Todo `EMPLOYEES.DEPARTMENT_ID` no nulo existe en `DEPARTMENTS` (FK).
- Toda fila de `JOB_HISTORY` referencia un empleado, puesto y (opcional)
  departamento válidos.

## Operaciones CRUD (comportamiento esperado)

| Operación | Efecto esperado |
|-----------|-----------------|
| Alta de empleado | Nuevo `EMPLOYEE_ID` desde `EMPLOYEES_SEQ` (≥ 1000); conteo +1 |
| Edición | Cambios persistidos; si cambia puesto/depto → fila de historial |
| Cambio de salario | Actualiza `SALARY`; **no** crea historial |
| Cambio de puesto/depto | Crea **1** fila en `JOB_HISTORY` con la asignación previa |
| Alta de departamento | Nuevo `DEPARTMENT_ID` desde `DEPARTMENTS_SEQ` (≥ 50) |

## Comportamiento del trigger (criterios)

1. `UPDATE EMPLOYEES SET JOB_ID='SUPERV' WHERE EMPLOYEE_ID=126` crea **una**
   fila en `JOB_HISTORY` para el empleado 126 con `JOB_ID='OPER'` (el previo) y
   `END_DATE = TRUNC(SYSDATE)`.
2. `UPDATE EMPLOYEES SET SALARY=SALARY+1 WHERE EMPLOYEE_ID=126` **no** crea
   historial.
3. La inserción de historial es **transaccional**: si la transacción hace
   `ROLLBACK`, la fila de historial no queda.

Verificado por `GeperIntegrationTest.changingAssignmentCreatesJobHistoryViaTrigger`
y `salaryOnlyChangeDoesNotCreateHistory` (ambos con rollback), y manualmente en
sqlplus.

## Búsqueda (contraste de seguridad)

| Entrada | Ruta normal (parametrizada) | Ruta lab (vulnerable) |
|---------|-----------------------------|------------------------|
| `mora` | 2 filas | 2 filas |
| `x') OR 1=1 --` | **0 filas** (literal) | **30 filas** (filtro subvertido) |
