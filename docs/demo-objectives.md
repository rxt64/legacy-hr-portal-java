# Objetivos de la demostración — GEPER

GEPER es el **estado legacy** de partida. Esta demo ejercita cuatro temas de
modernización. Nada de lo siguiente está implementado aquí; se documenta como
destino futuro, sin añadir instrucciones permanentes que impidan a un agente
modernizar o corregir el código después.

## Los cuatro temas

### 1. Modernización agéntica con supervisión técnica
Un agente puede analizar este repositorio (Java 8, Spring Boot 2.7, JDBC,
PL/SQL) y proponer cambios revisables: salto a Jakarta/Spring Boot 3,
reemplazo de SQL por una capa parametrizada uniforme, extracción de la lógica
del trigger, etc. La línea base en `functional-baseline.md` permite verificar
que cada cambio preserva el comportamiento.

### 2. Migración de base de datos a servicios administrados
Acoplamientos Oracle a resolver: **secuencias**, **trigger PL/SQL**, funciones
`NVL`/`ROUND`/`DUAL`. **Destino futuro propuesto (no implementado):
Java moderno + Azure Database for PostgreSQL**, con secuencias → `IDENTITY`/
`GENERATED`, y decisión explícita sobre reescribir el trigger o moverlo a la
aplicación.

### 3. Identificación y corrección de vulnerabilidades
Dos defectos intencionales verificables (`JAVA-SQLI-01`, `JAVA-XSS-01`) con
ruta de corrección y criterios de aceptación en `security-labs.md`. Permiten
demostrar el ciclo: detectar → explicar impacto → proponer fix → validar.

### 4. Preparación de aplicaciones y datos para futuras capacidades de IA
Datos sintéticos coherentes, diccionario de datos y una línea base estable
sobre la que construir, más adelante, consultas asistidas por IA (ver abajo).

## Destinos futuros (documentados, NO implementados)

| Aspecto | Hoy (legacy) | Destino futuro propuesto |
|---------|--------------|--------------------------|
| Lenguaje/runtime | Java 8, Spring Boot 2.7 | Java moderno (LTS), Spring Boot 3 |
| Base de datos | Oracle Database | **Azure Database for PostgreSQL** |
| IDs | Secuencias Oracle | Identidades/serial del motor destino |
| Historial | Trigger PL/SQL | Trigger del motor destino o lógica en la app |

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
