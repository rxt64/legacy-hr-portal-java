# Seguridad — GEPER

## Este repositorio contiene vulnerabilidades INTENCIONALES

GEPER es un **laboratorio de seguridad local**. Incluye, a propósito, defectos
de seguridad pequeños y verificables para que herramientas de análisis y
agentes de modernización puedan **encontrarlos, explicar su impacto y proponer
la corrección**. 

**No es una plantilla de producción.** No lo despliegue en Internet ni lo use
como punto de partida para un sistema real sin corregir primero los defectos
documentados.

## Condiciones del laboratorio

- Las rutas vulnerables se habilitan **exclusivamente** con la variable
  `ENABLE_VULNERABILITY_LABS=true`. El valor por defecto es **`false`**.
- No basta el nombre del entorno/perfil: además de la variable, cada petición a
  `/lab/**` debe llegar por **loopback** (`127.0.0.1` / `::1`); en caso
  contrario se devuelve 404 (`LabLoopbackFilter`).
- Con el modo deshabilitado, las rutas de laboratorio **no se registran**
  (los beans son condicionales) y devuelven **404**.
- El perfil `local-lab` enlaza el servidor a `127.0.0.1`.
- Solo se usan **datasets sintéticos**. La cuenta de base de datos de los
  ejercicios (`GEPER_LABRO`) tiene **permisos mínimos de solo lectura**.
- **No** se usa `SYS`, `SYSTEM` ni `sa` como cuenta de ejecución.
- **No** hay conexiones a sistemas externos, credenciales reales ni scripts que
  publiquen la aplicación en Internet.
- Las pantallas normales son funcionales y están **separadas** de los
  ejercicios.

Cuando el laboratorio está activo se muestra una banda visible:
**“Laboratorio vulnerable activo · Datos ficticios”**.

## Vulnerabilidades incluidas

| ID | Categoría | CWE | Archivo principal |
|----|-----------|-----|-------------------|
| `JAVA-SQLI-01` | Inyección SQL (JDBC `Statement`) | CWE-89 | `src/main/java/com/monteazul/geper/lab/LabSearchRepository.java` |
| `JAVA-XSS-01` | XSS almacenado (render sin escape) | CWE-79 | `src/main/resources/templates/lab/view.html` + `lab/LabController.java` |

El detalle completo (reproducción, causa raíz, impacto, corrección esperada y
criterio de aceptación) está en [docs/security-labs.md](docs/security-labs.md).

## Distinción importante

Este repositorio diferencia explícitamente:

- **Tecnología antigua** — Java 8, Spring Boot 2.7, JDBC directo. Es la línea
  base legacy a propósito; no es por sí misma una vulnerabilidad.
- **Tecnología fuera de soporte** — depende de la fecha; se documenta como
  consideración de modernización, no como CVE.
- **Vulnerabilidad conocida verificada (CVE)** — **no** se atribuye ningún CVE a
  ningún componente en este repositorio, porque no se ha verificado versión +
  componente afectados. No se añaden librerías vulnerables innecesarias.
- **Vulnerabilidad educativa introducida aquí** — los dos casos `SECURITY-LAB`
  anteriores, marcados en el código.

## Reporte

Al ser un laboratorio con defectos intencionales y datos ficticios, no hay un
proceso de divulgación responsable. Si encuentra un problema **fuera** de los
casos `SECURITY-LAB` documentados, abra un issue en el repositorio.

## Declaración sobre herramientas

Ninguna afirmación de este repositorio dice que una herramienta automática
detectó un problema. Los defectos están documentados porque fueron
**introducidos deliberadamente** por los autores, no porque un escáner los
reportara.
