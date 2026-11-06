# GEPER — Registro Central de Personal

> **Aplicación ficticia de demostración.** Institución ficticia:
> **Corporación Regional Monte Azul**. Todos los nombres, datos y cifras son
> inventados y no corresponden a ninguna persona u organización real.

GEPER (*Gestión de Personal y Puestos*) es una **aplicación legacy funcional**
construida a propósito sobre un stack empresarial de ~2012 para servir como
*línea base* en un laboratorio de modernización y seguridad. No es una
plantilla de producción.

- **Java 8** (bytecode objetivo 1.8)
- **Spring Boot 2.7.18** + **Maven**
- **Oracle Database** (probado contra Oracle Free 23c), driver **ojdbc8**
- Interfaz **renderizada en servidor** con Thymeleaf (intranet estilo 2012)
- Objetos Oracle reales: `NUMBER`/`VARCHAR2`, **secuencias**, **trigger
  `UPDATE_JOB_HISTORY`** y consultas específicas de Oracle

El propósito es que herramientas como GitHub Copilot y agentes de
modernización analicen, migren y corrijan esta base después. **No** incluye
versiones modernizadas, infraestructura de nube ni funcionalidades de IA.

---

## 1. Funcionalidades (pantallas normales)

| Área | Detalle |
|------|---------|
| Tablero | Empleados, departamentos, puestos, suma y promedio salarial — **todo calculado en Oracle** |
| Empleados | Búsqueda por nombre / departamento / puesto, ficha, alta y edición |
| Cambios | Salario; puesto y departamento (generan **historial** vía trigger) |
| Puestos | Catálogo con rangos salariales mínimo/máximo |
| Departamentos | Listado, ficha y **resumen salarial por departamento** |
| Historial laboral | Asignaciones previas cerradas por el trigger |

## 2. Requisitos

- JDK 8+ (el proyecto compila a bytecode 1.8; se probó con JDK 21 como JDK de build)
- Maven 3.8+
- Una base Oracle local. La forma más rápida es Docker:

```bash
./scripts/provision-local-db.sh
```

Ese script levanta un contenedor **Oracle Free** enlazado solo a `127.0.0.1`,
crea las cuentas de permisos mínimos y carga el esquema y los datos sintéticos.

> Las cuentas son `GEPER_OWNER` (dueña del esquema, uso administrativo),
> `GEPER_APP` (**cuenta de ejecución**, permisos mínimos) y `GEPER_LABRO`
> (solo lectura, usada únicamente por el laboratorio de SQLi). **No se usa
> `SYS`, `SYSTEM` ni ninguna cuenta privilegiada como cuenta de ejecución.**

### Provisión manual (sqlplus / SQLcl)

```bash
# como DBA (SYSTEM) en la PDB:
@db/accounts/01_create_accounts.sql
# como GEPER_OWNER:
@db/schema/02_schema.sql
@db/data/03_synthetic_data.sql
```

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
restablecer el ejercicio de XSS: `db/reset/90_reset_lab.sql`.

## 5. Pruebas

```bash
# Unitarias/offline (no requieren Oracle): gating de labs, loopback, SQL string
mvn test

# Integración contra una base local (funcional + trigger):
export GEPER_IT_JDBC_URL='jdbc:oracle:thin:@//localhost:1521/FREEPDB1'
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

- [infra/azure/README.md](infra/azure/README.md) — **IaC en Bicep (`mexicocentral`), Oracle 12c R2, Azure Front Door y operación en Azure**
- [docs/architecture.md](docs/architecture.md) — arquitectura y acoplamientos
- [docs/data-dictionary.md](docs/data-dictionary.md) — diccionario de datos
- [docs/functional-baseline.md](docs/functional-baseline.md) — línea base verificable
- [docs/security-labs.md](docs/security-labs.md) — ejercicios de seguridad
- [docs/demo-objectives.md](docs/demo-objectives.md) — objetivos de la demo
- [SECURITY.md](SECURITY.md) — naturaleza del laboratorio
- [ATTRIBUTIONS.md](ATTRIBUTIONS.md) — atribuciones

## 7. Estructura

```
db/            Scripts SQL: accounts/ schema/ data/ reset/
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
