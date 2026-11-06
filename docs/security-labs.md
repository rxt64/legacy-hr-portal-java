# Ejercicios de seguridad — GEPER

Laboratorio **local** con vulnerabilidades intencionales sobre datos
sintéticos. Activación:

```bash
export ENABLE_VULNERABILITY_LABS=true
export GEPER_DB_PASSWORD='App#Lab2012'
export GEPER_LAB_DB_PASSWORD='LabRo#Lab2012'
mvn spring-boot:run -Dspring-boot.run.profiles=local-lab
# luego, por loopback: http://localhost:8080/lab
```

Con el flag en `false` (por defecto) las rutas `/lab/**` no existen (404).
Cada caso está marcado en el código con
`SECURITY-LAB: <ID> — vulnerabilidad intencional para demostración local`.

---

## JAVA-SQLI-01 — Inyección SQL en JDBC

- **Categoría / CWE:** Inyección SQL · **CWE-89**
- **Archivo y método:** `src/main/java/com/monteazul/geper/lab/LabSearchRepository.java`,
  métodos `buildSql(String)` y `vulnerableSearch(String)`
- **Endpoint:** `GET /lab/sqli?term=...` (`lab/LabController.sqli`)
- **Cuenta de BD:** `GEPER_LABRO`, **solo lectura** (solo `SELECT` sobre datos
  sintéticos), vía un datasource separado (`LabDataSourceConfig`).

### Requisitos para activarlo
`ENABLE_VULNERABILITY_LABS=true`, acceso por loopback, base local provista.

### Entrada controlada por el usuario → construcción → punto de llegada
1. **Entrada:** el parámetro de consulta `term` (campo "Apellido contiene").
2. **Construcción:** en `buildSql`, `term` se **concatena** dentro del literal
   del `LIKE`:
   ```java
   "... WHERE UPPER(e.LAST_NAME) LIKE UPPER('%" + term + "%') ORDER BY e.LAST_NAME"
   ```
3. **Llegada a PostgreSQL:** en `vulnerableSearch`, la cadena se ejecuta con un
   `java.sql.PreparedStatement` vinculado (remediado en la tarea
   `001-upgrade-java21-springboot35`).

### Reproducción local inocua
1. Buscar `mora` → filtra a **2 filas** (apellidos que contienen "mora").
2. Buscar `x') OR 1=1 --` → el filtro se subvierte y devuelve **las 30 filas**
   del personal sintético. La página muestra el SQL exacto enviado.

**Resultado observable:** el conteo de resultados salta de 2 a 30; el `WHERE`
efectivo queda `LIKE UPPER('%x') OR 1=1` (el resto queda comentado por `--`).
Sin modificación de datos ni ejecución de comandos (la cuenta es de solo
lectura; probado: `UPDATE` devuelve `ORA-41900 missing UPDATE privilege`).

### Causa raíz
Concatenación de entrada no confiable en el texto SQL y uso de `Statement` en
lugar de parámetros vinculados.

### Impacto conceptual
Un atacante altera la lógica del filtro; con una superficie mayor podría leer
filas no previstas. Acotado aquí a lectura de datos sintéticos por la cuenta de
permisos mínimos.

### Corrección recomendada (futura, **no aplicada** en el caso vulnerable)
Usar `PreparedStatement`/bind variables, como ya hace la ruta normal
`EmployeeRepository.search` (`NamedParameterJdbcTemplate` con `:name`).

### Criterio de aceptación de la corrección
- La búsqueda usa parámetros vinculados; `term` nunca se concatena al SQL.
- Con `term = x') OR 1=1 --` el resultado es **0 filas** (texto tratado como
  literal), igual que la ruta normal (ver
  `GeperIntegrationTest.parameterizedSearchTreatsInjectionTextAsLiteral`).

---

## JAVA-XSS-01 — XSS almacenado

- **Categoría / CWE:** Cross-Site Scripting almacenado · **CWE-79**
- **Archivos:** almacenamiento `lab/LabController.xssStore`; render vulnerable
  `src/main/resources/templates/lab/view.html` (usa `th:utext`, sin escape).
  La ficha normal `templates/employees/detail.html` usa `th:text` (escapada).
- **Endpoints:** `GET/POST /lab/xss`, `GET /lab/xss/view/{id}`,
  `POST /lab/xss/reset/{id}`.

### Requisitos para activarlo
`ENABLE_VULNERABILITY_LABS=true`, acceso por loopback, base local provista.

### Flujo entrada → almacenamiento → render
1. **Entrada:** campo "Observaciones" en `/lab/xss`.
2. **Almacenamiento:** se guarda tal cual en `EMPLOYEES.OBSERVATIONS` mediante
   la ruta normal de escritura (cuenta `GEPER_APP`).
3. **Render vulnerable:** `/lab/xss/view/{id}` muestra el valor con
   `th:utext` (**sin escape HTML**). La misma columna en la ficha normal se
   muestra escapada con `th:text`.

### Reproducción local inocua
1. En `/lab/xss` elegir un empleado y guardar como observación:
   `<b>LAB</b> <script>document.title='XSS-LAB'</script>`
2. Abrir `/lab/xss/view/{id}`: el `<b>` se interpreta y el script cambia el
   **título de la pestaña** a `XSS-LAB`.
3. Abrir la ficha normal `/empleados/{id}`: el mismo texto aparece **escapado**
   (se ve el markup como texto, no se ejecuta).

**Resultado observable:** cambio de un texto visible (el título) solo en la
vista de laboratorio. Sin lectura de cookies, exfiltración ni llamadas
externas.

### Restablecimiento
`db/migration/postgres/90_pg_reset_lab.sql` restaura las observaciones al baseline sembrado.
También `POST /lab/xss/reset/{id}` limpia el empleado puntual.

### Causa raíz
Salida almacenada renderizada sin codificación contextual de HTML.

### Impacto conceptual
Script almacenado que se ejecuta en el navegador de cualquiera que abra la
vista afectada (en un sistema real: secuestro de sesión, acciones en nombre del
usuario). Aquí acotado a un cambio visible inocuo.

### Corrección recomendada (futura)
Codificación de salida contextual (escape por defecto, `th:text`); si se
requiere HTML enriquecido, sanitizar con una allow-list (p. ej. OWASP Java
HTML Sanitizer).

### Criterio de aceptación de la corrección
- La vista de laboratorio deja de ejecutar el script (se renderiza escapado o
  sanitizado).
- El contenido almacenado `<script>...</script>` aparece como texto inerte.

---

## Pruebas

Tres grupos separados (ver `src/test/java/com/monteazul/geper`):

1. **Funcionales normales** — `GeperIntegrationTest` (grupo 1): tablero,
   búsqueda parametrizada, alta, trigger de historial, cambio de salario sin
   historial. Requiere base local (`GEPER_IT_JDBC_URL`).
2. **Labs deshabilitados por defecto** — `LabConfigurationTest` y
   `LabLoopbackFilterTest` (grupo 2, offline): verifican que sin el flag no hay
   beans de laboratorio y que las rutas `/lab/**` dan 404; y que el filtro
   loopback bloquea accesos no-loopback. `GeperIntegrationTest` también verifica
   `GET /lab/sqli → 404` con los labs apagados.
3. **Caracterización del comportamiento vulnerable (opcional)** —
   `LabSearchSqlTest` (offline, nivel de cadena) y
   `LabVulnerabilityCharacterizationIT` (requiere `GEPER_LAB_IT=1` + base
   local). Confirman que el defecto existe; **no** afirman que la aplicación
   sea segura.

> Que una prueba confirme que la vulnerabilidad existe **no** marca la
> aplicación como segura. Las pruebas de laboratorio solo deben ejecutarse
> contra instancias locales creadas para este repositorio.

### Resultado de ejecución registrado

Ejecutado el 2026-11-06 contra Oracle Free 23c local (`gvenzl/oracle-free`)
antes de la migración de base de datos (tarea
`002-transform-oracle-to-postgresql`); re-ejecutar contra PostgreSQL local
(`postgres:16-alpine`, ver `scripts/provision-local-db.sh`) actualiza estos
números si cambian:

```
GeperIntegrationTest .................. Tests run: 9,  Failures: 0, Errors: 0
LabConfigurationTest .................. Tests run: 4,  Failures: 0, Errors: 0
LabLoopbackFilterTest ................. Tests run: 3,  Failures: 0, Errors: 0
LabSearchSqlTest ...................... Tests run: 2,  Failures: 0, Errors: 0
LabVulnerabilityCharacterizationIT .... Tests run: 2,  Failures: 0, Errors: 0
```
