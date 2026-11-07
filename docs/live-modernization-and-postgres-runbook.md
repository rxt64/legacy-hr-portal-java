# Runbook en Vivo: Modernización Agéntica de GEPER y Migración de Oracle 12c R2 a Azure Database for PostgreSQL

> **Propósito:** Guía operativa verificada para la sesión en vivo de **60 minutos** de **GEPER** (*Corporación Regional Monte Azul*), integrando el flujo **Assess → Plan → Execute** de **GitHub Copilot Modernization Agent (`modernize` CLI v1.0.91)** con el recorrido de **20–25 minutos de conversión de esquema/PLSQL, transferencia offline y validación** desde **Oracle Database 12c Release 2 (`12.2.0.1.0`)** hacia **Azure Database for PostgreSQL Flexible Server (PostgreSQL 16)** en **Mexico Central (`mexicocentral`)**.

---

## 1. Cronograma integrado de la demostración (60 minutos)

| Bloque | Duración objetivo | Duración medida en ensayo | Actividad en vivo | Checkpoint de respaldo (transparente, preejecutado) |
|---|---:|---:|---|---|
| **Bloque 1: Verificación del origen Oracle 12c R2 y Front Door** | 5 min | **1.0 s** (consulta SQL) | Mostrar GEPER legacy en Azure Front Door (`https://geper-lab-kt2comvd-bfc4erb7h0dhgkdu.b02.azurefd.net/`) y ejecutar [`00_verify_oracle_source_and_witness.sql`](../db/migration/postgres/00_verify_oracle_source_and_witness.sql) confirmando versión `12.2.0.1.0`, PDB `GEPERPDB`, secuencias y trigger `UPDATE_JOB_HISTORY`. | Salida verificada en este documento |
| **Bloque 2: Fase Assess (`modernize assess`)** | 8 min | **3 min 29 s** (`217.25 s`) | Ejecutar `modernize assess` y revisar hallazgos (JDK 1.8 EOL, Spring Boot 2.7 EOL, ausencia de `Dockerfile`, acoplamiento JDBC). | Reporte preejecutado en `.github/modernize/assessment/` |
| **Bloque 3: Fase Plan (`modernize plan create`)** | 7 min | **3 min 30 s** (`210.16 s`) | Generar `plan.md` y `tasks.json` detectando las skills [`geper-java8-to-java21-springboot35`](../.github/skills/geper-java8-to-java21-springboot35/SKILL.md) y [`geper-oracle12c-to-postgresql-migration`](../.github/skills/geper-oracle12c-to-postgresql-migration/SKILL.md). | `.github/modernize/geper-java21-pg-aca/plan.md` en rama `rehearsal/modernization-dryrun` |
| **Bloque 4: Conversión Oracle → PostgreSQL, Transferencia Offline y Validación** | **20–25 min** | **~2 s** (ejecución de scripts) + explicación guiada | 1) Revisar conversión asistida de tipos, secuencias y trigger PL/SQL → PL/pgSQL (`SECURITY DEFINER`) en la base temporal `geper_conversion_check`; 2) Crear empleada testigo (`Camila Testigo-Migracion`), pausar escrituras y transferir datos en orden de FK hacia PostgreSQL (`geper`); 3) Validar conteos, sumas, `NULL`, secuencias y rollback transaccional del trigger. | Base preejecutada **`geper_rehearsal`** en `pg-geper-kt2comvd.postgres.database.azure.com` (con los 31 empleados y el trigger validado); la base **`geper`** permanece vacía lista para la demo en vivo |
| **Bloque 5: Fase Execute (`modernize plan execute`) y Seguridad** | 12 min | **~11 min** (Tasks 000–003 + CVE scan) | Ejecutar actualización a Java 21 / Spring Boot 3.5 (`jakarta.*`), adaptación de consultas (`NVL` → `COALESCE`, `NEXTVAL FROM DUAL` → `nextval()`) y remediación de `JAVA-SQLI-01` (`PreparedStatement`) y `JAVA-XSS-01` (`th:text`). | Rama `rehearsal/modernization-dryrun` (commit `3759d7f`) |
| **Bloque 6: Publicación en Azure Container Apps y Validación** | 8 min | **1 min 50 s** (`110.24 s` ACR) + **1 min 13 s** (`72.8 s` ACA) | Construir contenedor en `acrlegacylabbkt2comvd.azurecr.io` y desplegar en `cae-legacy-modern-mxc` conectado por Private Endpoint (`10.42.6.5`) a `pg-geper-kt2comvd`. | Imagen preconstruida `acrlegacylabbkt2comvd.azurecr.io/geper-modern-rehearsal:v1` |

---

## 2. Diferenciación explícita: Capacidades nativas vs. Herramientas externas vs. Skills personalizadas

| Componente / Fase | Categoría real | Qué hace exactamente | Intervención del presentador |
|---|---|---|---|
| `modernize` CLI (`v1.0.91`) | **Producto nativo** (GitHub Copilot Modernization Agent) | Ejecuta `assess`, `plan create` y `plan execute`; congela baseline de pruebas (`000-setupBaseline`), migra Java 8 → 21 y Spring Boot 2.7 → 3.5, transforma repositorios JDBC usando la skill del proyecto y ejecuta escaneo/parcheo de CVEs Maven (`003-security-cve-remediation`). | Ejecutar los comandos CLI y revisar los reportes de cada tarea en `.github/modernize/geper-java21-pg-aca/`. |
| Extensión PostgreSQL de VS Code (`ms-ossdata.vscode-postgresql`) / `psql 13.16` | **Herramienta externa complementaria** | Inspección interactiva del catálogo de `pg-geper-kt2comvd.postgres.database.azure.com`, validación asistida del DDL convertido en `geper_conversion_check` y ejecución de consultas SQL/PLpgSQL. | Conectar a `geper_conversion_check` y `geper` durante el Bloque 4. |
| `.github/skills/geper-*/SKILL.md` | **Skills personalizadas de proyecto** | Enseñan a `modernize` el mapeo exacto de `UPDATE_JOB_HISTORY` a PL/pgSQL (`SECURITY DEFINER`), el reemplazo de `NVL`/`DUAL`/`NEXTVAL` y la remediación de `JAVA-SQLI-01` y `JAVA-XSS-01`. | Mostrar los archivos `SKILL.md` en VS Code antes de `modernize plan create`. |
| `db/migration/postgres/02_offline_transfer_oracle_to_pg.sh` | **Script complementario de transferencia de datos** | Extrae los registros de Oracle 12c R2 (`12.2.0.1.0`) en orden de FK con formato ISO-8601 y carga/sincroniza secuencias en PostgreSQL 16. **No es una función nativa de `modernize` CLI.** | Ejecutar el script en `vm-geper-ora` durante el Bloque 4. |

---

## 3. Objetivo listo para la fase Plan (`modernize plan create`)

```powershell
$geperGoal = "Upgrade GEPER from Java 8 and Spring Boot 2.7 to Java 21 and Spring Boot 3.5, migrate database access from Oracle 12c R2 (ojdbc8, NVL, DUAL, sequences, trigger UPDATE_JOB_HISTORY) to Azure Database for PostgreSQL Flexible Server with PL/pgSQL trigger, remediate JAVA-SQLI-01 (PreparedStatement) and JAVA-XSS-01 (Thymeleaf th:text escaping), and containerize for Azure Container Apps."

modernize assess --source . --format markdown
modernize plan create $geperGoal --source . --plan-name "geper-java21-pg-aca" --language java --overwrite
```

---

## 4. Runbook de 20–25 minutos: Conversión, Transferencia y Validación Oracle 12c R2 → PostgreSQL 16

### Etapa 1 (Minutos 0–5): Verificación real del origen Oracle 12c R2 (`12.2.0.1.0`)
En `vm-geper-ora`:
```bash
source /etc/geper/credentials.env
su - oracle -c "export ORACLE_HOME=/u01/app/oracle/product/12.2.0/dbhome_1 PATH=/u01/app/oracle/product/12.2.0/dbhome_1/bin:\$PATH; \
  sqlplus -s \"GEPER_OWNER/${ORA_OWNER_PW}@//127.0.0.1:1521/GEPERPDB\" @/var/opt/geper/migration/postgres/00_verify_oracle_source_and_witness.sql"
```
**Evidencia verificada en el origen:**
- Motor: `Oracle Database 12c Enterprise Edition Release 12.2.0.1.0 - 64bit Production`
- Contenedor PDB: `GEPERPDB` (`CURRENT_SCHEMA = GEPER_OWNER`)
- Conteos base: `DEPARTMENTS = 6`, `JOBS = 10`, `EMPLOYEES = 30`, `NULL_OBSERVATIONS_CNT = 22`, `JOB_HISTORY = 4`, `TOTAL_SALARY = 99800`, `AVG_SALARY = 3326.67`
- Secuencias: `DEPARTMENTS_SEQ (LAST_NUMBER = 80, INCREMENT_BY = 10)`, `EMPLOYEES_SEQ (LAST_NUMBER = 1001, INCREMENT_BY = 1)`
- Trigger: `UPDATE_JOB_HISTORY` (`BEFORE EACH ROW UPDATE ON EMPLOYEES`, `ENABLED`)

### Etapa 2 (Minutos 5–12): Conversión separada de esquema y lógica PL/SQL → PL/pgSQL en `geper_conversion_check`
> **Nota del presentador:** *"Separamos la conversión de esquema/PLSQL de la transferencia de datos. Probamos primero el DDL convertido ([`01_pg_schema_and_plpgsql_trigger.sql`](../db/migration/postgres/01_pg_schema_and_plpgsql_trigger.sql)) contra la base temporal `geper_conversion_check` en `pg-geper-kt2comvd.postgres.database.azure.com`."*

| Objeto / Tipo en Oracle 12c R2 | Conversión en PostgreSQL 16 | Detalle técnico clave |
|---|---|---|
| `NUMBER(6)` | `INTEGER` | Claves primarias y foráneas (`department_id`, `employee_id`). |
| `NUMBER(9,2)` | `NUMERIC(9,2)` | Precisión monetaria exacta para salarios (`min_salary`, `max_salary`, `salary`) sin coma flotante. |
| `VARCHAR2(n)` | `VARCHAR(n)` | Codificación `UTF8` verificada (ej. apellidos con `ñ` como `Zuñiga`, `Ureña`, `Nuñez`). |
| `DATE` + `DEFAULT SYSDATE` | `DATE` + `DEFAULT CURRENT_DATE` | En Oracle `DATE` incluye hora; en GEPER representa fechas calendario (`TRUNC(SYSDATE)`), mapeado a `DATE` ISO `YYYY-MM-DD`. |
| `DEPARTMENTS_SEQ` / `EMPLOYEES_SEQ` | `SEQUENCE ... NO CYCLE` | Sincronizadas post-carga con `setval(..., max_id, true)` para evitar colisiones `23505` (`duplicate key`). |
| Trigger `UPDATE_JOB_HISTORY` | `FUNCTION geper_owner.fn_update_job_history() SECURITY DEFINER` + `TRIGGER update_job_history` | En PostgreSQL un trigger requiere una función `RETURNS TRIGGER`. El atributo `SECURITY DEFINER SET search_path = geper_owner, public` conserva el modelo de mínimo privilegio de Oracle (`geper_app` no tiene `INSERT` directo sobre `job_history`). |

Comando de validación en la base temporal:
```bash
export PGSSLMODE=require
psql -h pg-geper-kt2comvd.postgres.database.azure.com -U geperpgadmin -d geper_conversion_check \
  -v ON_ERROR_STOP=1 -f /var/opt/geper/migration/postgres/01_pg_schema_and_plpgsql_trigger.sql
```

### Etapa 3 (Minutos 12–18): Registro testigo, pausa de escrituras y transferencia offline hacia `geper`
> **Nota del presentador:** *"Insertamos ahora el registro testigo (`Camila Testigo-Migracion`, `EMPLOYEE_ID = 1001`, `SALARY = 4150.00`, `DEPARTMENT_ID = 40`), detenemos `geper.service` para pausar escrituras en Oracle, y ejecutamos la transferencia offline en orden estricto de integridad referencial: `1) DEPARTMENTS → 2) JOBS → 3) EMPLOYEES → 4) JOB_HISTORY`, seguida de `setval()` en ambas secuencias."*

```bash
export PG_HOST="pg-geper-kt2comvd.postgres.database.azure.com"
export PG_DB="geper"
export PG_ADMIN_USER="geperpgadmin"
export PG_ADMIN_PASSWORD="<PG_ADMIN_PASSWORD>"
export INSERT_WITNESS="true"
export FREEZE_SOURCE="true"
/var/opt/geper/migration/postgres/02_offline_transfer_oracle_to_pg.sh
```
> **Checkpoint de respaldo:** La base **`geper_rehearsal`** en `pg-geper-kt2comvd.postgres.database.azure.com` ya contiene esta transferencia preejecutada completa, mientras que la base **`geper`** se mantiene con `0` tablas lista para ejecutarse en vivo durante la sesión.

### Etapa 4 (Minutos 18–25): Validaciones post-migración, prueba transaccional del trigger y política de reversión
El script ejecuta automáticamente como `geper_app` (mínimo privilegio) las comprobaciones de paridad y la prueba transaccional con `ROLLBACK`:

1. **Paridad de conteos, nulos y agregados (verificada en `geper_rehearsal`):**
   - `departments_cnt = 6`, `jobs_cnt = 10`, `employees_cnt = 31` (30 originales + `1001 Camila Testigo-Migracion`)
   - `null_observations_cnt = 22` (conservación exacta de `NULL` vs cadenas vacías)
   - `job_history_cnt = 4` (el trigger `BEFORE UPDATE` no se dispara durante el `INSERT` de carga inicial)
   - `total_salary = 103950.00` (`99800.00` base + `4150.00` testigo), `avg_salary = 3353.23`
   - Departamento `40 (Tecnología)`: pasa de `6` empleados (`18,450.00`) a `7` empleados (`22,600.00`).
2. **Prueba transaccional del trigger `update_job_history` en PostgreSQL:**
   - Dentro de `BEGIN; UPDATE geper_owner.employees SET job_id = 'SUPERV' WHERE employee_id = 126;`, el trigger `SECURITY DEFINER` inserta exactamente 1 fila en `geper_owner.job_history` (`employee_id = 126, start_date = 2014-09-15, end_date = 2026-11-06, job_id = 'OPER', department_id = 60`).
   - Al ejecutar `ROLLBACK;`, la fila de historial se revierte transaccionalmente y `job_history_cnt` permanece en `4`.
3. **Política de reversión (antes vs. después de habilitar escrituras en PostgreSQL):**
   - **Antes de abrir tráfico de escritura en PostgreSQL:** Oracle 12c R2 (`GEPERPDB`) conserva intactos todos los datos hasta el instante de la pausa. Basta con ejecutar `sudo systemctl start geper.service` en `vm-geper-ora` para reanudar inmediatamente sobre Oracle sin pérdida de datos.
   - **Después de habilitar escrituras en PostgreSQL:** Cualquier alta de empleado, cambio salarial o movimiento de puesto/historial realizado en PostgreSQL **no se replica hacia Oracle**. Revertir la conexión a Oracle después de haber aceptado escrituras en PostgreSQL descartaría esas operaciones salvo que antes se exporten e inserten manualmente las filas con `employee_id > 1001` y los cambios de `job_history`.
