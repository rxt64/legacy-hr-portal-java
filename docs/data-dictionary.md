# Diccionario de datos — GEPER

Esquema PostgreSQL `geper_owner`, propiedad del rol `geper_owner`. Todos los
datos son sintéticos. Convertido desde el esquema Oracle original en la tarea
`002-transform-oracle-to-postgresql` (ver
`db/migration/postgres/01_pg_schema_and_roles.sql`).

## departments
| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `department_id` | `INTEGER` | NO | PK. Alimentada por `departments_seq` |
| `department_name` | `VARCHAR(60)` | NO | Único |
| `location` | `VARCHAR(80)` | SÍ | Ubicación |

## jobs
| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `job_id` | `VARCHAR(12)` | NO | PK (código, p. ej. `DESARR`) |
| `job_title` | `VARCHAR(60)` | NO | Título |
| `min_salary` | `NUMERIC(9,2)` | SÍ | Rango mínimo |
| `max_salary` | `NUMERIC(9,2)` | SÍ | Rango máximo (`CHECK max_salary>=min_salary`) |

## employees
| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `employee_id` | `INTEGER` | NO | PK. Alimentada por `employees_seq` |
| `first_name` | `VARCHAR(40)` | NO | Nombre |
| `last_name` | `VARCHAR(40)` | NO | Apellidos |
| `email` | `VARCHAR(80)` | SÍ | Único |
| `hire_date` | `DATE` | NO | Ingreso (`DEFAULT CURRENT_DATE`) |
| `job_id` | `VARCHAR(12)` | NO | FK → `jobs` |
| `salary` | `NUMERIC(9,2)` | NO | `CHECK salary > 0` |
| `department_id` | `INTEGER` | SÍ | FK → `departments` |
| `assignment_start_date` | `DATE` | NO | Inicio de la asignación actual; mantenido por el trigger |
| `observations` | `VARCHAR(2000)` | SÍ | Notas; almacenamiento del lab XSS |

Índices: `ix_emp_dept(department_id)`, `ix_emp_job(job_id)`, `ix_emp_last(last_name)`.

## job_history
| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `employee_id` | `INTEGER` | NO | PK compuesta, FK → `employees` |
| `start_date` | `DATE` | NO | PK compuesta; inicio de la asignación cerrada |
| `end_date` | `DATE` | NO | Fin (`CHECK end_date>=start_date`) |
| `job_id` | `VARCHAR(12)` | NO | FK → `jobs` (puesto previo) |
| `department_id` | `INTEGER` | SÍ | FK → `departments` (departamento previo) |

## Secuencias
| Nombre | Start | Incremento |
|--------|-------|-----------|
| `departments_seq` | 70 | 10 |
| `employees_seq` | 1000 | 1 |

## Trigger

| Nombre | Evento | Lógica |
|--------|--------|--------|
| `update_job_history` (ejecuta `geper_owner.fn_update_job_history()`, `SECURITY DEFINER`) | `BEFORE UPDATE OF job_id, department_id ON employees`, por fila | Si cambia puesto o departamento: inserta en `job_history` la asignación previa y adelanta `assignment_start_date` a `CURRENT_DATE`. No se dispara por cambio de salario. |

## Relaciones (resumen)

```
departments 1───* employees *───1 jobs
      ^                 │
      │                 * (al cambiar puesto/depto, vía trigger)
      └──────────── job_history ───┘
```
