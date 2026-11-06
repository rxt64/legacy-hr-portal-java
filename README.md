# GEPER — Registro Central de Personal

> **Aplicación ficticia de demostración.** Institución ficticia:
> **Corporación Regional Monte Azul**. Todos los nombres, datos y cifras son
> inventados y no corresponden a ninguna persona u organización real.

GEPER (*Gestión de Personal y Puestos*) es una **aplicación legacy funcional**
construida a propósito sobre un stack empresarial de ~2012 para servir como
*línea base* en un laboratorio de modernización y seguridad. No es una
plantilla de producción.

- **Java 21** (Spring Boot 3.5, Jakarta EE 10)
- **Spring Boot 3.5.0** + **Maven**
- **Azure Database for PostgreSQL Flexible Server** (PostgreSQL 16), driver **org.postgresql:postgresql**
- Interfaz **renderizada en servidor** con Thymeleaf (intranet estilo 2012)
- Objetos PostgreSQL nativos: `INTEGER`/`VARCHAR`/`NUMERIC`, **secuencias**,
  **función de trigger `fn_update_job_history()`** (PL/pgSQL, equivalente al
  antiguo trigger Oracle `UPDATE_JOB_HISTORY`) y consultas en dialecto ANSI
  SQL (`COALESCE`, `nextval(...)`)

El propósito es que herramientas como GitHub Copilot y agentes de
modernización analicen, migren y corrijan esta base después. **No** incluye
versiones modernizadas, infraestructura de nube ni funcionalidades de IA.

---

## 1. Funcionalidades (pantallas normales)

| Área | Detalle |
|------|---------|
| Tablero | Empleados, departamentos, puestos, suma y promedio salarial — **todo calculado en PostgreSQL** |
| Empleados | Búsqueda por nombre / departamento / puesto, ficha, alta y edición |
| Cambios | Salario; puesto y departamento (generan **historial** vía trigger) |
| Puestos | Catálogo con rangos salariales mínimo/máximo |
| Departamentos | Listado, ficha y **resumen salarial por departamento** |
| Historial laboral | Asignaciones previas cerradas por el trigger |

## 2. Requisitos

- JDK 21+
- Maven 3.8+
- Una base PostgreSQL local. La forma más rápida es Docker:

```bash
./scripts/provision-local-db.sh
```

Ese script levanta un contenedor **PostgreSQL 16** enlazado solo a
`127.0.0.1`, crea los roles de permisos mínimos y carga el esquema, el
trigger y los datos sintéticos.

> Los roles son `geper_owner` (dueño del esquema, uso administrativo),
> `geper_app` (**cuenta de ejecución**, permisos mínimos) y `geper_labro`
> (solo lectura, usada únicamente por el laboratorio de SQLi). **No se usa
> ningún rol superusuario como cuenta de ejecución.**

### Provisión manual (psql)

```bash
# como superusuario/admin (p. ej. postgres):
psql -f db/migration/postgres/01_pg_schema_and_roles.sql
psql -f db/migration/postgres/02_pg_trigger_update_job_history.sql
# como geper_owner (o el mismo superusuario):
psql -f db/migration/postgres/03_pg_synthetic_data.sql
```

Para el plan de transferencia de datos existentes desde Oracle 12c R2, ver
[docs/migration/oracle-to-postgresql-data-transfer-plan.md](docs/migration/oracle-to-postgresql-data-transfer-plan.md).

## 3. Ejecutar la aplicación normal

```bash
export GEPER_DB_PASSWORD='App#Lab2012'      # contraseña lab del contenedor
mvn spring-boot:run
```

Abrir <http://localhost:8080/>. Los laboratorios de seguridad quedan
**deshabilitados** (no hay rutas `/lab/**`).

La configuración por defecto (`src/main/resources/application.yml`) **no
contiene secretos**: lee cada credencial de variables de entorno
(`GEPER_DB_URL`, `GEPER_DB_USER`, `GEPER_DB_PASSWORD`).

## 4. Ejercicios locales de seguridad (opcional, separado)

> ⚠️ Solo para uso local con datos sintéticos. Ver **[SECURITY.md](SECURITY.md)**
> y **[docs/security-labs.md](docs/security-labs.md)**.

Las rutas vulnerables se habilitan **exclusivamente** con
`ENABLE_VULNERABILITY_LABS=true` (valor por defecto `false`) **y** solo
responden a peticiones por *loopback*. Con el modo deshabilitado esas rutas
**no se registran** y devuelven 404.

```bash
export ENABLE_VULNERABILITY_LABS=true
export GEPER_DB_PASSWORD='App#Lab2012'
export GEPER_LAB_DB_PASSWORD='LabRo#Lab2012'
mvn spring-boot:run -Dspring-boot.run.profiles=local-lab
```

Con los labs activos aparece una banda visible **“Laboratorio vulnerable
activo · Datos ficticios”** y el menú **Laboratorio** (`/lab`). Para
restablecer el ejercicio de XSS: `db/migration/postgres/90_pg_reset_lab.sql`.

## 5. Pruebas

```bash
# Unitarias/offline (no requieren PostgreSQL): gating de labs, loopback, SQL string
mvn test

# Integración contra una base local (funcional + trigger):
export GEPER_IT_JDBC_URL='jdbc:postgresql://localhost:5432/geper'
export GEPER_IT_JDBC_PASSWORD='App#Lab2012'
mvn test

# Caracterización opcional del comportamiento vulnerable (labs + base local):
export GEPER_LAB_IT=1 GEPER_LAB_JDBC_PASSWORD='LabRo#Lab2012'
mvn -Dtest=LabVulnerabilityCharacterizationIT -DfailIfNoTests=false test
```

Los tres grupos de prueba están descritos en
[docs/security-labs.md](docs/security-labs.md#pruebas). Las pruebas de
laboratorio solo deben ejecutarse contra instancias locales creadas para este
repositorio.

## 6. Documentación

- [infra/azure/README.md](infra/azure/README.md) — **IaC en Bicep (`mexicocentral`), VM legacy Oracle 12c R2, Azure Front Door y operación en Azure** (infraestructura heredada; pendiente de reemplazo por Azure Database for PostgreSQL Flexible Server / Azure Container Apps en una tarea de despliegue posterior)
- [docs/architecture.md](docs/architecture.md) — arquitectura y acoplamientos
- [docs/data-dictionary.md](docs/data-dictionary.md) — diccionario de datos
- [docs/functional-baseline.md](docs/functional-baseline.md) — línea base verificable
- [docs/security-labs.md](docs/security-labs.md) — ejercicios de seguridad
- [docs/demo-objectives.md](docs/demo-objectives.md) — objetivos de la demo
- [docs/migration/oracle-to-postgresql-data-transfer-plan.md](docs/migration/oracle-to-postgresql-data-transfer-plan.md) — plan de transferencia de datos Oracle → PostgreSQL
- [SECURITY.md](SECURITY.md) — naturaleza del laboratorio
- [ATTRIBUTIONS.md](ATTRIBUTIONS.md) — atribuciones

## 7. Estructura

```
db/            Scripts SQL: migration/postgres/ (esquema, roles, trigger, datos, reset)
scripts/       provision-local-db.sh
src/main/java/com/monteazul/geper/
  config/      Gating de labs (propiedades, filtro loopback, atributos)
  domain/      Entidades
  repository/  Acceso a datos PARAMETRIZADO (ruta normal segura)
  service/     Lógica transaccional
  web/         Controladores de las pantallas normales
  lab/         SECURITY-LAB: SQLi + XSS (condicional)
src/main/resources/templates/   Vistas Thymeleaf
config/        application-local-lab.yml.example
```
