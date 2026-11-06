# Modernization Plan: GEPER Java 21 / Spring Boot 3.5 / PostgreSQL / Azure Container Apps

**Project**: GEPER (com.monteazul:geper)

---

## Technical Framework

- **Language**: Java 8
- **Framework**: Spring Boot 2.7.18 (javax.* / Jakarta EE 8)
- **Build Tool**: Maven
- **Database**: Oracle Database 12c Release 2 (12.2.0.1.0) via `ojdbc8`
- **Key Dependencies**: Spring Web, Spring Thymeleaf, Spring JDBC, Spring Validation, Oracle JDBC driver

---

## Overview

> This migration upgrades GEPER from a legacy Java 8 / Spring Boot 2.7 stack running against an Oracle 12c R2
> database on a dedicated VM, to a modern Java 21 / Spring Boot 3.5 (Jakarta EE) application backed by Azure
> Database for PostgreSQL Flexible Server, deployed as a container on Azure Container Apps. The new
> architecture will:
>
> - Run on a current, supported Java/Spring Boot runtime (Jakarta EE namespaces, Java 21 language features).
> - Replace the Oracle-specific schema, sequences, PL/SQL trigger (`UPDATE_JOB_HISTORY`), and JDBC SQL
>   dialect (`NVL`, `DUAL`, `NEXTVAL`, `SYSDATE`) with PostgreSQL-native equivalents, including an
>   equivalent PL/pgSQL trigger.
> - Remediate the identified SQL injection (`JAVA-SQLI-01`) and reflected XSS (`JAVA-XSS-01`) findings.
> - Remove known vulnerable dependencies (CVE remediation) prior to deployment.
> - Package the application as a container and deploy it to Azure Container Apps, replacing the
>   VM-hosted deployment model.
>
> The migration proceeds in dependency order: runtime/framework upgrade and security code fixes first,
> then the database migration, then dependency CVE remediation, then verification via integration tests,
> and finally containerized deployment to Azure Container Apps.

---

## Migration Impact Summary

| Application | Original Service | New Azure Service | Authentication | Comments |
|-------------|------------------|-------------------|-----------------|----------|
| GEPER | Oracle Database 12c R2 (VM, `ojdbc8`) | Azure Database for PostgreSQL Flexible Server | Managed Identity (default) | Schema, sequences, `UPDATE_JOB_HISTORY` trigger, and JDBC SQL dialect migrated |
| GEPER | Java 8 / Spring Boot 2.7 app on VM | Azure Container Apps | Managed Identity (default) | Java 21 / Spring Boot 3.5 (Jakarta EE), containerized |

---

## Open Questions & Questionnaire

- [ ] Q: The latest stable Spring Boot release is 4.x (Spring Framework 7.x, Java 25 baseline), but this
  plan targets Spring Boot 3.5.x on Java 21 exactly as requested and as implemented by the project skill
  `geper-java8-to-java21-springboot35`. Confirm Spring Boot 3.5.x / Java 21 is the intended target rather
  than Spring Boot 4.x / Java 25.
- [ ] Q: The repository's existing `infra/azure` Bicep targets the legacy VM + Oracle 12c stack
  (`vm-geper-ora`, Azure Front Door). It does not define Azure Container Apps or PostgreSQL Flexible
  Server resources. This plan assumes those target resources will be provisioned as part of the
  deployment task rather than via a separate infrastructure-provisioning task — confirm this is acceptable,
  or indicate if a dedicated Bicep/Terraform infrastructure task should be added first.
- [ ] Q: Integration tests are planned in Mock mode by default (no live Azure Database for PostgreSQL
  Flexible Server instance is currently available to the baseline project) — confirm, or provide
  subscription/resource details to run tests in Real mode against actual Azure resources.
