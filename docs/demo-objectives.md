# Objetivos de la demostración — GEPER

GEPER partió de un **estado legacy** (Java 8 / Spring Boot 2.7 / Oracle) y
ejercita cuatro temas de modernización. Los temas 1 y 2 ya se implementaron
en este repositorio (tareas `001-upgrade-java21-springboot35` y
`002-transform-oracle-to-postgresql`); el resto permanece como destino
futuro documentado, sin añadir instrucciones permanentes que impidan a un
agente modernizar o corregir el código después.

## Los cuatro temas

### 1. Modernización agéntica con supervisión técnica
Un agente puede analizar este repositorio (Java 8, Spring Boot 2.7, JDBC,
PL/SQL) y proponer cambios revisables: salto a Jakarta/Spring Boot 3,
reemplazo de SQL por una capa parametrizada uniforme, extracción de la lógica
del trigger, etc. La línea base en `functional-baseline.md` permite verificar
que cada cambio preserva el comportamiento.

### 2. Migración de base de datos a servicios administrados
Acoplamientos Oracle resueltos (tarea `002-transform-oracle-to-postgresql`):
**secuencias**, **trigger PL/SQL**, funciones `NVL`/`ROUND`/`DUAL`. **Destino
implementado: Java 21 / Spring Boot 3.5 + Azure Database for PostgreSQL
Flexible Server**, con secuencias Oracle convertidas a secuencias nativas de
PostgreSQL (`employees_seq`/`departments_seq`) y el trigger reescrito como
una función PL/pgSQL `SECURITY DEFINER` (`fn_update_job_history()`) que
preserva el comportamiento y los permisos originales.

### 3. Identificación y corrección de vulnerabilidades
Dos defectos intencionales verificables (`JAVA-SQLI-01`, `JAVA-XSS-01`) con
ruta de corrección y criterios de aceptación en `security-labs.md`. Permiten
demostrar el ciclo: detectar → explicar impacto → proponer fix → validar.

### 4. Preparación de aplicaciones y datos para futuras capacidades de IA
Datos sintéticos coherentes, diccionario de datos y una línea base estable
sobre la que construir, más adelante, consultas asistidas por IA (ver abajo).

## Estado de los destinos (algunos ya implementados)

| Aspecto | Antes (legacy) | Estado actual |
|---------|--------------|--------------------------|
| Lenguaje/runtime | Java 8, Spring Boot 2.7 | **Java 21, Spring Boot 3.5** (implementado, tarea `001`) |
| Base de datos | Oracle Database | **Azure Database for PostgreSQL Flexible Server** (implementado, tarea `002`) |
| IDs | Secuencias Oracle | Secuencias nativas de PostgreSQL (`employees_seq`/`departments_seq`) |
| Historial | Trigger PL/SQL | Función de trigger PL/pgSQL `SECURITY DEFINER` |

## Ejemplos conceptuales de consultas asistidas por IA (futuro)

> Conceptuales. **No** se implementan agentes ni modelos en este repositorio.
> Cada ejemplo indica su **requisito de autorización**.

1. *"¿Qué empleados están por debajo del mínimo salarial de su puesto?"*
   → join `EMPLOYEES`×`JOBS` donde `SALARY < MIN_SALARY`.
   **Autorización:** rol RRHH con acceso de lectura a compensación.
2. *"Resumen de rotación por departamento el último año"* → agregación sobre
   `JOB_HISTORY`. **Autorización:** rol RRHH/gerencia; datos agregados.
3. *"Historial de un empleado"* → `JOB_HISTORY` del empleado.
   **Autorización:** el propio empleado o RRHH; **nunca** otro empleado sin
   permiso (análogo a la lección de autorización por objeto del laboratorio de
   SIGEA).

Toda futura capacidad de IA debe aplicar control de acceso **antes** de
responder: autenticación del solicitante y autorización por rol/propiedad del
dato, no solo relevancia de la consulta.
