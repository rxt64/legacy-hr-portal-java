# Attributions

This repository (GEPER) is original work released under the MIT License (see
`LICENSE`). It was written from scratch for a modernization and security lab.
No private source, no private Git history, and no code of unknown provenance
were copied in.

## Design inspiration (not copied)

- **Oracle "HR" sample schema** — The relational shape of this lab (the
  `EMPLOYEES` / `JOBS` / `DEPARTMENTS` / `JOB_HISTORY` tables, sequences, and
  especially the `UPDATE_JOB_HISTORY` row trigger that records prior
  assignments) is modelled after the well-known Oracle HR sample schema,
  which Oracle publishes under the Apache License 2.0
  (https://github.com/oracle-samples/db-sample-schemas). The table and trigger
  *names and structure* follow that familiar teaching example so the lab is
  recognisable, but **all data in `db/data/` is fictitious and original** and
  the DDL/PL/SQL here was authored for this project. No rows, comments, or
  files from the Oracle sample were copied.

  A future modernization effort is free to restructure or replace any of this.

## Third-party runtime dependencies

Resolved at build time by Maven; not redistributed in this repository:

- Spring Boot 2.7.x and its transitive dependencies (Apache License 2.0)
- Oracle JDBC driver `ojdbc8` (Oracle Free Use Terms and Conditions / OTN
  license) — downloaded from Maven Central, not vendored here.

No third-party binaries or images are distributed in this repository.
