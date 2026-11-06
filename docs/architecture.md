# Arquitectura actual — GEPER

Documenta el estado de la aplicación tras la migración de base de datos
(tarea `002-transform-oracle-to-postgresql`): Java 21 / Spring Boot 3.5
sobre **Azure Database for PostgreSQL Flexible Server**. El despliegue en
Azure Container Apps y el reemplazo de la infraestructura VM+Oracle en
`infra/azure` son objeto de una tarea de despliegue posterior (ver
`.github/modernize/geper-java21-pg-aca/plan.md`).

## Vista general

```
Navegador  ──HTTP──>  Spring Boot 3.5 (Tomcat embebido, Jakarta EE 10)
                         │
                         ├── Controladores MVC (Thymeleaf, render en servidor)
                         ├── Servicios (@Transactional)
                         ├── Repositorios (Spring JDBC: JdbcTemplate / Named)
                         │
                         └──JDBC (org.postgresql:postgresql)──>  Azure Database for PostgreSQL Flexible Server
                                                 ├── Tablas INTEGER/VARCHAR/NUMERIC
                                                 ├── Secuencias (departments_seq, employees_seq)
                                                 └── Trigger PL/pgSQL fn_update_job_history()
```

Todo el HTML se **renderiza en el servidor** con Thymeleaf; no hay API REST ni
SPA. El estado vive íntegramente en PostgreSQL.

## Stack y versiones

| Componente | Versión | Nota de modernización |
|------------|---------|-----------------------|
| Java (bytecode) | 21 | Upgraded desde 1.8 en la tarea `001-upgrade-java21-springboot35` |
| Spring Boot | 3.5.0 | Jakarta EE 10 (`jakarta.*`) |
| Maven | 3.8+ | — |
| PostgreSQL JDBC | org.postgresql:postgresql (gestionado por el BOM de Spring Boot) | Reemplaza `ojdbc8` |
| PostgreSQL | 16 (Azure Database for PostgreSQL Flexible Server en producción; `postgres:16-alpine` en el laboratorio local) | Esquema/secuencias/trigger convertidos en `002-transform-oracle-to-postgresql` |
| Thymeleaf | el de Spring Boot 3.5 | Render en servidor |

## Acoplamientos resueltos por la migración de base de datos

1. **Esquema y tipos.** `NUMBER`/`VARCHAR2`/`DATE` de Oracle se convirtieron a
   `INTEGER`/`NUMERIC`/`VARCHAR`/`DATE` nativos de PostgreSQL
   (`db/migration/postgres/01_pg_schema_and_roles.sql`).
2. **Secuencias.** `EMPLOYEES_SEQ`/`DEPARTMENTS_SEQ` (Oracle) se convirtieron a
   secuencias nativas de PostgreSQL `employees_seq`/`departments_seq`,
   consumidas desde Java con `SELECT nextval('employees_seq')` /
   `SELECT nextval('departments_seq')` en vez de `... NEXTVAL FROM DUAL`.
3. **Trigger de historial laboral.** El antiguo trigger PL/SQL
   `UPDATE_JOB_HISTORY` se reescribió como una función PL/pgSQL
   `geper_owner.fn_update_job_history()` + trigger `update_job_history`
   (`db/migration/postgres/02_pg_trigger_update_job_history.sql`), preservando
   el mismo disparo (`BEFORE UPDATE OF job_id, department_id`, con la misma
   guarda `WHEN`) y los mismos derechos de definidor (`SECURITY DEFINER`).
   La regla "cambiar puesto/departamento genera historial" sigue viviendo en
   la base de datos, no en la capa Java (ver criterios en
   `functional-baseline.md`).
4. **Dialecto SQL.** `NVL(x, y)` se reemplazó por el equivalente ANSI
   `COALESCE(x, y)` (compatible con ambos motores) en
   `DashboardRepository`/`DepartmentRepository`. `ALTER SESSION SET
   CURRENT_SCHEMA = GEPER_OWNER` se reemplazó por
   `SET search_path TO geper_owner, public` en el `connection-init-sql` del
   datasource (`application.yml`, `LabDataSourceConfig`).
5. **`javax.*` → `jakarta.*`.** Resuelto previamente en la tarea
   `001-upgrade-java21-springboot35`.

## Cuentas y permisos mínimos

| Rol (PostgreSQL) | Función | Privilegios |
|--------|-----|-------------|
| `geper_owner` | Dueño del esquema y los datos | DDL sobre sus objetos; **no** es cuenta de ejecución |
| `geper_app` | **Ejecución** de la app | `SELECT/INSERT/UPDATE/DELETE` sobre tablas operativas, `SELECT` en historial y secuencias; **sin** `INSERT` en `job_history` |
| `geper_labro` | Solo laboratorio SQLi | `SELECT` sobre datos sintéticos; nada más |

El historial lo escribe la función de trigger con **derechos del definidor**
(`SECURITY DEFINER`, propiedad de `geper_owner`), por eso `geper_app` no
necesita `INSERT` en `job_history` (un intento directo falla por falta de
privilegio, el equivalente PostgreSQL del antiguo `ORA-41900` de Oracle).

## Capas de código

| Paquete | Responsabilidad |
|---------|-----------------|
| `web` | Controladores de pantallas normales |
| `service` | Transacciones (los cambios de asignación son atómicos con el trigger) |
| `repository` | SQL **parametrizado** (ruta segura) |
| `domain` | Entidades |
| `config` | Gating de laboratorio: `LabProperties`, `LabLoopbackFilter`, `GlobalModelAttributes` |
| `lab` | Código vulnerable **condicional** (`@ConditionalOnProperty`) |

## Flujo del trigger (resumen)

`BEFORE UPDATE OF job_id, department_id ON employees`, por fila, con guardia
`WHEN` para disparar solo ante un cambio real. Inserta en `job_history` la
asignación previa (desde `assignment_start_date` del `OLD` hasta
`CURRENT_DATE`) y adelanta `NEW.assignment_start_date`. Un cambio de salario
no lo dispara.
