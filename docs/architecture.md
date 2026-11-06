# Arquitectura actual — GEPER

Documenta el estado **legacy** y sus acoplamientos reales, como insumo para la
modernización posterior. No describe ningún destino implementado.

## Vista general

```
Navegador  ──HTTP──>  Spring Boot 2.7 (Tomcat embebido)
                         │
                         ├── Controladores MVC (Thymeleaf, render en servidor)
                         ├── Servicios (@Transactional)
                         ├── Repositorios (Spring JDBC: JdbcTemplate / Named)
                         │
                         └──JDBC (ojdbc8)──>  Oracle Database
                                                 ├── Tablas NUMBER/VARCHAR2
                                                 ├── Secuencias
                                                 └── Trigger PL/SQL UPDATE_JOB_HISTORY
```

Todo el HTML se **renderiza en el servidor** con Thymeleaf; no hay API REST ni
SPA. El estado vive íntegramente en Oracle.

## Stack y versiones

| Componente | Versión | Nota de modernización |
|------------|---------|-----------------------|
| Java (bytecode) | 1.8 | Objetivo legacy; el JDK de build puede ser mayor |
| Spring Boot | 2.7.18 | Rama legacy (Jakarta `javax.*`) |
| Maven | 3.8+ | — |
| Oracle JDBC | ojdbc8 21.9.0.0 | Driver específico de Oracle |
| Oracle DB | probado en Free 23c | Secuencias y PL/SQL atan a Oracle |
| Thymeleaf | el de Spring Boot 2.7 | Render en servidor |

## Acoplamientos reales (lo que una migración debe resolver)

1. **Oracle-específico.** Las claves primarias se alimentan de **secuencias**
   (`EMPLOYEES_SEQ`, `DEPARTMENTS_SEQ`). El historial laboral lo mantiene un
   **trigger PL/SQL** (`UPDATE_JOB_HISTORY`), no la capa Java. Hay funciones
   Oracle en consultas (`NVL`, `ROUND`, `DUAL`, concatenación `||`).
   Migrar el motor exige reemplazar secuencias (p. ej. `IDENTITY`/`SERIAL`) y
   decidir si el trigger se reescribe en el motor destino o se mueve a la capa
   de aplicación.
2. **`javax.*` (Jakarta EE 8).** Spring Boot 2.7 usa `javax.servlet` y
   `javax.validation`. Un salto a Spring Boot 3 / Jakarta 9+ implica el cambio
   de namespace `javax → jakarta`.
3. **Resolución de esquema por sesión.** El runtime fija
   `ALTER SESSION SET CURRENT_SCHEMA = GEPER_OWNER` (init SQL de Hikari) en vez
   de sinónimos. Es un acoplamiento operativo a revisar en la migración.
4. **Lógica de negocio en la base.** La regla "cambiar puesto/departamento
   genera historial" vive en el trigger. Cualquier reescritura debe preservar
   ese comportamiento (ver criterios en `functional-baseline.md`).

## Cuentas y permisos mínimos

| Cuenta | Rol | Privilegios |
|--------|-----|-------------|
| `GEPER_OWNER` | Dueña del esquema y los datos | DDL sobre sus objetos; **no** es cuenta de ejecución |
| `GEPER_APP` | **Ejecución** de la app | `SELECT/INSERT/UPDATE/DELETE` sobre tablas operativas, `SELECT` en historial y secuencias; **sin** `INSERT` en `JOB_HISTORY` |
| `GEPER_LABRO` | Solo laboratorio SQLi | `SELECT` sobre datos sintéticos; nada más |

El historial lo escribe el trigger con **derechos del definidor**
(`GEPER_OWNER`), por eso `GEPER_APP` no necesita `INSERT` en `JOB_HISTORY`
(verificado: intento directo → `ORA-41900`).

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

`BEFORE UPDATE OF JOB_ID, DEPARTMENT_ID ON EMPLOYEES`, por fila, con guardia
`WHEN` para disparar solo ante un cambio real. Inserta en `JOB_HISTORY` la
asignación previa (desde `ASSIGNMENT_START_DATE` del `:OLD` hasta `SYSDATE`) y
adelanta `:NEW.ASSIGNMENT_START_DATE`. Un cambio de salario no lo dispara.
