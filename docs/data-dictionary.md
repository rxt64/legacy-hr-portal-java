# Diccionario de datos — GEPER

Esquema Oracle propiedad de `GEPER_OWNER`. Todos los datos son sintéticos.

## DEPARTMENTS
| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `DEPARTMENT_ID` | `NUMBER(6)` | NO | PK. Alimentada por `DEPARTMENTS_SEQ` |
| `DEPARTMENT_NAME` | `VARCHAR2(60)` | NO | Único |
| `LOCATION` | `VARCHAR2(80)` | SÍ | Ubicación |

## JOBS
| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `JOB_ID` | `VARCHAR2(12)` | NO | PK (código, p. ej. `DESARR`) |
| `JOB_TITLE` | `VARCHAR2(60)` | NO | Título |
| `MIN_SALARY` | `NUMBER(9,2)` | SÍ | Rango mínimo |
| `MAX_SALARY` | `NUMBER(9,2)` | SÍ | Rango máximo (`CHECK MAX>=MIN`) |

## EMPLOYEES
| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `EMPLOYEE_ID` | `NUMBER(6)` | NO | PK. Alimentada por `EMPLOYEES_SEQ` |
| `FIRST_NAME` | `VARCHAR2(40)` | NO | Nombre |
| `LAST_NAME` | `VARCHAR2(40)` | NO | Apellidos |
| `EMAIL` | `VARCHAR2(80)` | SÍ | Único |
| `HIRE_DATE` | `DATE` | NO | Ingreso (`DEFAULT SYSDATE`) |
| `JOB_ID` | `VARCHAR2(12)` | NO | FK → `JOBS` |
| `SALARY` | `NUMBER(9,2)` | NO | `CHECK SALARY > 0` |
| `DEPARTMENT_ID` | `NUMBER(6)` | SÍ | FK → `DEPARTMENTS` |
| `ASSIGNMENT_START_DATE` | `DATE` | NO | Inicio de la asignación actual; mantenido por el trigger |
| `OBSERVATIONS` | `VARCHAR2(2000)` | SÍ | Notas; almacenamiento del lab XSS |

Índices: `IX_EMP_DEPT(DEPARTMENT_ID)`, `IX_EMP_JOB(JOB_ID)`, `IX_EMP_LAST(LAST_NAME)`.

## JOB_HISTORY
| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `EMPLOYEE_ID` | `NUMBER(6)` | NO | PK compuesta, FK → `EMPLOYEES` |
| `START_DATE` | `DATE` | NO | PK compuesta; inicio de la asignación cerrada |
| `END_DATE` | `DATE` | NO | Fin (`CHECK END>=START`) |
| `JOB_ID` | `VARCHAR2(12)` | NO | FK → `JOBS` (puesto previo) |
| `DEPARTMENT_ID` | `NUMBER(6)` | SÍ | FK → `DEPARTMENTS` (departamento previo) |

## Secuencias
| Nombre | Start | Incremento |
|--------|-------|-----------|
| `DEPARTMENTS_SEQ` | 50 | 10 |
| `EMPLOYEES_SEQ` | 1000 | 1 |

## Trigger
| Nombre | Evento | Lógica |
|--------|--------|--------|
| `UPDATE_JOB_HISTORY` | `BEFORE UPDATE OF JOB_ID, DEPARTMENT_ID ON EMPLOYEES`, por fila | Si cambia puesto o departamento: inserta en `JOB_HISTORY` la asignación previa y adelanta `ASSIGNMENT_START_DATE`. No se dispara por cambio de salario. |

## Relaciones (resumen)

```
DEPARTMENTS 1───* EMPLOYEES *───1 JOBS
      ^                 │
      │                 * (al cambiar puesto/depto, vía trigger)
      └──────────── JOB_HISTORY ───┘
```
