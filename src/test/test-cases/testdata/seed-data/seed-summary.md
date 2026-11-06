# Seed Data Summary (reference only — mirrors `db/data/03_synthetic_data.sql`)

This file summarizes the deterministic synthetic dataset loaded by
`db/data/03_synthetic_data.sql` so test cases can reference stable IDs
without re-embedding SQL. The post-migration environment (Mock mode, see
`infra-decision-table.md`) seeds an equivalent in-memory/mocked dataset with
the same shape.

## Departments (6 rows)

| ID | Name | Location |
|----|------|----------|
| 10 | Direccion General | Monte Azul Central |
| 20 | Recursos Humanos | Monte Azul Central |
| 30 | Finanzas | Torre Norte |
| 40 | Tecnologia | Torre Norte |
| 50 | Ventas | Sucursal Valle |
| 60 | Operaciones | Planta Sur |

## Jobs (10 rows)

| ID | Title | Min Salary | Max Salary |
|----|-------|-----------|-----------|
| DIR_GEN | Director General | 8000 | 15000 |
| GER_RRHH | Gerente de RRHH | 4500 | 9000 |
| ANAL_RH | Analista de RRHH | 1800 | 3500 |
| CONTAD | Contador | 2200 | 4200 |
| DESARR | Desarrollador | 2000 | 4800 |
| SOPORTE | Tecnico de Soporte | 1400 | 2600 |
| VENDE | Ejecutivo de Ventas | 1500 | 3800 |
| RECEP | Recepcionista | 1000 | 1700 |
| SUPERV | Supervisor de Planta | 2300 | 4500 |
| OPER | Operario | 1100 | 2000 |

## Employees (30 rows total)

Representative subset used by test cases below (full set in `db/data/03_synthetic_data.sql`):

| ID | Name | Job | Department | Salary | Observations |
|----|------|-----|------------|--------|---------------|
| 101 | Marisol Fonseca Arias | DIR_GEN | 10 | 13200 | "Fundadora del registro central." |
| 116 | Felipe Mora Zuñiga | SOPORTE | 40 | 2050 | NULL |
| 123 | Monica Alvarado Rios | SUPERV | 60 | 4300 | "Supervisa el turno diurno." |
| 126 | Luis Castillo Umaña | OPER | 60 | 1650 | NULL |
| 127 | Gabriela Rivera Salas | OPER | 60 | 1600 | NULL |

Aggregate baseline (whole dataset): 30 employees, 6 departments, 10 jobs,
total salary `99800` (matches `GeperIntegrationTest#dashboardAggregatesComeFromOracleAndMatchBaseline`).

An employee/department ID that does not exist in this seed (e.g. employee
`9999`, department `999`, job `NOPE`) is used throughout as the canonical
"not found" fixture.
