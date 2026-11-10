#!/usr/bin/env bash
# ==============================================================================
# GEPER - Aprovisionamiento inicial y actualización idempotente en VM Linux Azure
#
# - Distingue instalación inicial vs actualización (no elimina CDB/GEPERPDB ni
#   datos existentes en redespliegues).
# - Monta el disco administrado persistente (LUN 0 -> /u02) para datafiles Oracle.
# - Utiliza Oracle Database 12c Release 2 (12.2.0.1.0) nativo en la VM (desde la
#   imagen oficial de Oracle en Azure o desde linuxx64_12201_database.zip).
# - Configura el Listener en loopback (127.0.0.1:1521), crea la CDB ORCL12C y la
#   PDB GEPERPDB en /u02/oradata, y guarda el estado de apertura (SAVE STATE).
# - Genera credenciales únicas en /etc/geper/credentials.env (0600, sin imprimir).
# - Ejecuta SQL*Plus con WHENEVER SQLERROR EXIT SQL.SQLCODE (nunca CONTINUE).
# - Instala Java 8 (OpenJDK 1.8), crea el usuario sin privilegios 'geper',
#   configura systemd (oracle-cdb.service y geper.service) con inicio automático
#   y despliega GEPER con ENABLE_VULNERABILITY_LABS=false.
# ==============================================================================
set -euo pipefail

STAGE_DIR="${STAGE_DIR:-/var/opt/geper/stage}"
INSTALLER_ZIP="${INSTALLER_ZIP:-/var/opt/geper/installers/linuxx64_12201_database.zip}"
EXPECTED_SHA256="f8f9fa22f3c42f1fb2bc9ff2bb34d92b788d157d7d4b37541c3832860ebca677"
ORACLE_BASE="/u01/app/oracle"
ORACLE_HOME="/u01/app/oracle/product/12.2.0/dbhome_1"
ORACLE_SID="ORCL12C"
PDB_NAME="GEPERPDB"
ORADATA_MOUNT="/u02"
ORADATA_DIR="/u02/oradata"
CRED_DIR="/etc/geper"
CRED_FILE="${CRED_DIR}/credentials.env"
APP_ENV_FILE="${CRED_DIR}/geper.env"
APP_DIR="/opt/geper"

echo "==> [1/8] Configurando disco administrado persistente en ${ORADATA_MOUNT}..."
LUN0_DEV="/dev/disk/azure/scsi1/lun0"
if [ ! -b "$LUN0_DEV" ]; then
  for d in /dev/sdc /dev/sdd /dev/sdb; do
    if [ -b "$d" ] && ! mount | grep -q "^${d}"; then
      LUN0_DEV="$d"
      break
    fi
  done
fi

mkdir -p "$ORADATA_MOUNT"
if ! mountpoint -q "$ORADATA_MOUNT"; then
  if ! blkid "$LUN0_DEV" >/dev/null 2>&1; then
    echo "    Formateando disco persistente ${LUN0_DEV} como ext4..."
    mkfs.ext4 -F -L ORADATA "$LUN0_DEV" >/dev/null
  fi
  UUID=$(blkid -s UUID -o value "$LUN0_DEV")
  if ! grep -q "$UUID" /etc/fstab; then
    echo "UUID=${UUID} ${ORADATA_MOUNT} ext4 defaults,nofail 0 2" >> /etc/fstab
  fi
  mount "$ORADATA_MOUNT"
fi

echo "==> [2/8] Verificando instalación nativa de Oracle Database 12c Release 2 (12.2.0.1)..."
if [ ! -x "${ORACLE_HOME}/bin/sqlplus" ]; then
  if [ -f "$INSTALLER_ZIP" ]; then
    echo "    Verificando integridad SHA-256 de ${INSTALLER_ZIP}..."
    ACTUAL_SHA=$(sha256sum "$INSTALLER_ZIP" | awk '{print $1}')
    if [ "$ACTUAL_SHA" != "$EXPECTED_SHA256" ]; then
      echo "ERROR: Checksum SHA-256 inválido para ${INSTALLER_ZIP} (${ACTUAL_SHA})" >&2
      exit 1
    fi
    yum install -y oracle-database-server-12cR2-preinstall unzip >/dev/null
    mkdir -p "$ORACLE_HOME" /u01/app/oraInventory /var/opt/geper/unzip
    chown -R oracle:oinstall /u01 /var/opt/geper/unzip
    su - oracle -c "unzip -q -o '$INSTALLER_ZIP' -d /var/opt/geper/unzip"
    cat >/var/opt/geper/unzip/db_install.rsp <<EOF
oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v12.2.0
oracle.install.option=INSTALL_DB_SWONLY
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION=/u01/app/oraInventory
ORACLE_HOME=${ORACLE_HOME}
ORACLE_BASE=${ORACLE_BASE}
oracle.install.db.InstallEdition=EE
oracle.install.db.OSDBA_GROUP=dba
oracle.install.db.OSOPER_GROUP=oper
oracle.install.db.OSBACKUPDBA_GROUP=dba
oracle.install.db.OSDGDBA_GROUP=dba
oracle.install.db.OSKMDBA_GROUP=dba
oracle.install.db.OSRACDBA_GROUP=dba
SECURITY_UPDATES_VIA_MYORACLESUPPORT=false
DECLINE_SECURITY_UPDATES=true
EOF
    su - oracle -c "/var/opt/geper/unzip/database/runInstaller -silent -waitForCompletion -responseFile /var/opt/geper/unzip/db_install.rsp" || true
    /u01/app/oraInventory/orainstRoot.sh
    "${ORACLE_HOME}/root.sh"
    rm -rf /var/opt/geper/unzip
  else
    echo "ERROR: No se encontró Oracle 12.2.0.1 en ${ORACLE_HOME} ni el instalador ${INSTALLER_ZIP}." >&2
    exit 1
  fi
fi

mkdir -p "$ORADATA_DIR" "${ORADATA_MOUNT}/fast_recovery_area"
chown -R oracle:oinstall "$ORADATA_MOUNT"
chmod 750 "$ORADATA_DIR"

echo "==> [3/8] Generando o recuperando credenciales únicas en ${CRED_FILE}..."
mkdir -p "$CRED_DIR"
chmod 750 "$CRED_DIR"

gen_pw() {
  local rand
  rand=$(openssl rand -hex 6)
  echo "Gp${rand}#9a"
}

if [ ! -f "$CRED_FILE" ]; then
  cat >"$CRED_FILE" <<EOF
ORA_SYS_PW='$(gen_pw)'
ORA_OWNER_PW='$(gen_pw)'
ORA_APP_PW='$(gen_pw)'
ORA_LABRO_PW='$(gen_pw)'
EOF
  chmod 600 "$CRED_FILE"
fi
# shellcheck disable=SC1090
source "$CRED_FILE"

echo "==> [4/8] Configurando Oracle Net Listener en loopback (127.0.0.1:1521)..."
cat >"${ORACLE_HOME}/network/admin/listener.ora" <<EOF
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = 127.0.0.1)(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )
EOF
cat >"${ORACLE_HOME}/network/admin/sqlnet.ora" <<EOF
NAMES.DIRECTORY_PATH= (TNSNAMES, EZCONNECT)
SQLNET.INBOUND_CONNECT_TIMEOUT=120
EOF
chown oracle:oinstall "${ORACLE_HOME}/network/admin/listener.ora" "${ORACLE_HOME}/network/admin/sqlnet.ora"

echo "==> [5/8] Verificando o creando CDB (${ORACLE_SID}) y PDB (${PDB_NAME}) en disco persistente..."
if [ ! -d "${ORADATA_DIR}/${ORACLE_SID}" ] && [ ! -d "${ORADATA_DIR}/$(echo "$ORACLE_SID" | tr '[:upper:]' '[:lower:]')" ]; then
  echo "    Creando CDB ${ORACLE_SID} y PDB ${PDB_NAME} con DBCA (puede tardar varios minutos)..."
  su - oracle -c "export ORACLE_BASE=${ORACLE_BASE} ORACLE_HOME=${ORACLE_HOME} PATH=${ORACLE_HOME}/bin:\$PATH; \
    lsnrctl start >/dev/null 2>&1 || true; \
    dbca -silent -createDatabase \
      -templateName General_Purpose.dbc \
      -gdbName ${ORACLE_SID} \
      -sid ${ORACLE_SID} \
      -createAsContainerDatabase true \
      -numberOfPDBs 1 \
      -pdbName ${PDB_NAME} \
      -pdbAdminPassword \"${ORA_SYS_PW}\" \
      -sysPassword \"${ORA_SYS_PW}\" \
      -systemPassword \"${ORA_SYS_PW}\" \
      -characterSet AL32UTF8 \
      -databaseType MULTIPURPOSE \
      -memoryMgmtType AUTO_SGA \
      -totalMemory 4096 \
      -storageType FS \
      -datafileDestination \"${ORADATA_DIR}\" \
      -redoLogFileSize 50 \
      -emConfiguration NONE"
fi

if ! grep -q "^${ORACLE_SID}:" /etc/oratab 2>/dev/null; then
  echo "${ORACLE_SID}:${ORACLE_HOME}:Y" >> /etc/oratab
else
  sed -i "s|^${ORACLE_SID}:${ORACLE_HOME}:.*|${ORACLE_SID}:${ORACLE_HOME}:Y|" /etc/oratab
fi

cat >/usr/local/sbin/oracle-cdb-ctl.sh <<'EOCTL'
#!/usr/bin/env bash
set -euo pipefail
ORACLE_BASE="/u01/app/oracle"
ORACLE_HOME="/u01/app/oracle/product/12.2.0/dbhome_1"
ORACLE_SID="ORCL12C"
PDB_NAME="GEPERPDB"
export ORACLE_BASE ORACLE_HOME ORACLE_SID PATH="${ORACLE_HOME}/bin:${PATH}"

case "${1:-start}" in
  start)
    "${ORACLE_HOME}/bin/lsnrctl" status >/dev/null 2>&1 || "${ORACLE_HOME}/bin/lsnrctl" start
    if ! pgrep -f "ora_pmon_${ORACLE_SID}" >/dev/null 2>&1; then
      "${ORACLE_HOME}/bin/sqlplus" -s / as sysdba <<EOSQL
STARTUP;
EOSQL
    fi
    "${ORACLE_HOME}/bin/sqlplus" -s / as sysdba <<EOSQL
DECLARE
  v_mode VARCHAR2(32);
BEGIN
  SELECT open_mode INTO v_mode FROM v\$pdbs WHERE name = '${PDB_NAME}';
  IF v_mode <> 'READ WRITE' THEN
    EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE ${PDB_NAME} OPEN READ WRITE';
  END IF;
  EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE ${PDB_NAME} SAVE STATE';
END;
/
ALTER SYSTEM REGISTER;
EXIT;
EOSQL
    for _ in $(seq 1 45); do
      if "${ORACLE_HOME}/bin/lsnrctl" services | grep -qi "${PDB_NAME}"; then
        break
      fi
      sleep 2
    done
    ;;
  stop)
    if pgrep -f "ora_pmon_${ORACLE_SID}" >/dev/null 2>&1; then
      "${ORACLE_HOME}/bin/sqlplus" -s / as sysdba <<EOSQL
SHUTDOWN IMMEDIATE;
EXIT;
EOSQL
    fi
    "${ORACLE_HOME}/bin/lsnrctl" stop || true
    ;;
esac
EOCTL
chmod 755 /usr/local/sbin/oracle-cdb-ctl.sh

cat >/etc/systemd/system/oracle-cdb.service <<EOF
[Unit]
Description=Oracle Database 12c R2 (${ORACLE_SID} + ${PDB_NAME}) and Loopback Listener
After=network.target local-fs.target

[Service]
Type=oneshot
User=oracle
Group=oinstall
Environment="ORACLE_BASE=${ORACLE_BASE}"
Environment="ORACLE_HOME=${ORACLE_HOME}"
Environment="ORACLE_SID=${ORACLE_SID}"
ExecStart=/usr/local/sbin/oracle-cdb-ctl.sh start
ExecStop=/usr/local/sbin/oracle-cdb-ctl.sh stop
TimeoutStartSec=300
TimeoutStopSec=180
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable oracle-cdb.service
systemctl start oracle-cdb.service

echo "==> [6/8] Aprovisionando cuentas (GEPER_OWNER, GEPER_APP, GEPER_LABRO), esquema y datos en ${PDB_NAME}..."
su - oracle -c "export ORACLE_BASE=${ORACLE_BASE} ORACLE_HOME=${ORACLE_HOME} ORACLE_SID=${ORACLE_SID} PATH=${ORACLE_HOME}/bin:\$PATH; \
  sqlplus -s / as sysdba <<'EOSQL'
WHENEVER SQLERROR EXIT SQL.SQLCODE
DECLARE
  v_mode VARCHAR2(32);
BEGIN
  SELECT open_mode INTO v_mode FROM v\$pdbs WHERE name = '${PDB_NAME}';
  IF v_mode <> 'READ WRITE' THEN
    EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE ${PDB_NAME} OPEN READ WRITE';
  END IF;
  EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE ${PDB_NAME} SAVE STATE';
END;
/
ALTER SESSION SET CONTAINER = ${PDB_NAME};

DECLARE
  v_ts NUMBER;
  v_dir VARCHAR2(512);
BEGIN
  SELECT COUNT(*) INTO v_ts FROM dba_tablespaces WHERE tablespace_name = 'USERS';
  IF v_ts = 0 THEN
    SELECT SUBSTR(name, 1, INSTR(name, '/', -1)) INTO v_dir FROM v\$datafile WHERE ROWNUM = 1;
    EXECUTE IMMEDIATE 'CREATE TABLESPACE USERS DATAFILE ''' || v_dir || 'users01.dbf'' SIZE 100M AUTOEXTEND ON NEXT 50M MAXSIZE UNLIMITED';
  END IF;
  EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE DEFAULT TABLESPACE USERS';
END;
/

DECLARE
  v_cnt NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_cnt FROM all_users WHERE username = 'GEPER_OWNER';
  IF v_cnt = 0 THEN
    EXECUTE IMMEDIATE 'CREATE USER GEPER_OWNER IDENTIFIED BY \"${ORA_OWNER_PW}\" DEFAULT TABLESPACE USERS TEMPORARY TABLESPACE TEMP';
  ELSE
    EXECUTE IMMEDIATE 'ALTER USER GEPER_OWNER IDENTIFIED BY \"${ORA_OWNER_PW}\" DEFAULT TABLESPACE USERS TEMPORARY TABLESPACE TEMP account unlock';
  END IF;
  EXECUTE IMMEDIATE 'GRANT CREATE SESSION, CREATE TABLE, CREATE SEQUENCE, CREATE TRIGGER, CREATE VIEW, CREATE SYNONYM TO GEPER_OWNER';
  EXECUTE IMMEDIATE 'ALTER USER GEPER_OWNER QUOTA UNLIMITED ON USERS';

  SELECT COUNT(*) INTO v_cnt FROM all_users WHERE username = 'GEPER_APP';
  IF v_cnt = 0 THEN
    EXECUTE IMMEDIATE 'CREATE USER GEPER_APP IDENTIFIED BY \"${ORA_APP_PW}\" DEFAULT TABLESPACE USERS TEMPORARY TABLESPACE TEMP';
  ELSE
    EXECUTE IMMEDIATE 'ALTER USER GEPER_APP IDENTIFIED BY \"${ORA_APP_PW}\" DEFAULT TABLESPACE USERS TEMPORARY TABLESPACE TEMP account unlock';
  END IF;
  EXECUTE IMMEDIATE 'GRANT CREATE SESSION TO GEPER_APP';

  SELECT COUNT(*) INTO v_cnt FROM all_users WHERE username = 'GEPER_LABRO';
  IF v_cnt = 0 THEN
    EXECUTE IMMEDIATE 'CREATE USER GEPER_LABRO IDENTIFIED BY \"${ORA_LABRO_PW}\" DEFAULT TABLESPACE USERS TEMPORARY TABLESPACE TEMP';
  ELSE
    EXECUTE IMMEDIATE 'ALTER USER GEPER_LABRO IDENTIFIED BY \"${ORA_LABRO_PW}\" DEFAULT TABLESPACE USERS TEMPORARY TABLESPACE TEMP account unlock';
  END IF;
  EXECUTE IMMEDIATE 'GRANT CREATE SESSION TO GEPER_LABRO';
END;
/
ALTER SYSTEM REGISTER;
EXIT;
EOSQL"

# Verificar si el esquema de GEPER_OWNER ya está creado (preservar datos en redespliegues)
HAS_TABLES=$(su - oracle -c "export ORACLE_HOME=${ORACLE_HOME} ORACLE_SID=${ORACLE_SID} PATH=${ORACLE_HOME}/bin:\$PATH; \
  sqlplus -s / as sysdba <<'EOSQL'
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
ALTER SESSION SET CONTAINER = ${PDB_NAME};
SELECT COUNT(*) FROM dba_tables WHERE owner = 'GEPER_OWNER' AND table_name = 'EMPLOYEES';
EXIT;
EOSQL" | tr -d '[:space:]')

if [ "$HAS_TABLES" = "0" ]; then
  echo "    Instalación inicial detectada en ${PDB_NAME}: aplicando 02_schema.sql y 03_synthetic_data.sql..."
  chmod -R a+rX "$STAGE_DIR"
  su - oracle -c "export ORACLE_HOME=${ORACLE_HOME} PATH=${ORACLE_HOME}/bin:\$PATH; \
    sqlplus -s \"GEPER_OWNER/${ORA_OWNER_PW}@//127.0.0.1:1521/${PDB_NAME}\" <<'EOSQL'
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET DEFINE OFF
@${STAGE_DIR}/db/schema/02_schema.sql
@${STAGE_DIR}/db/data/03_synthetic_data.sql
EXIT;
EOSQL"
else
  echo "    Esquema existente detectado en ${PDB_NAME}: preservando datos y verificando grants..."
  su - oracle -c "export ORACLE_HOME=${ORACLE_HOME} PATH=${ORACLE_HOME}/bin:\$PATH; \
    sqlplus -s \"GEPER_OWNER/${ORA_OWNER_PW}@//127.0.0.1:1521/${PDB_NAME}\" <<'EOSQL'
WHENEVER SQLERROR EXIT SQL.SQLCODE
GRANT SELECT, INSERT, UPDATE, DELETE ON EMPLOYEES   TO GEPER_APP;
GRANT SELECT, INSERT, UPDATE, DELETE ON DEPARTMENTS TO GEPER_APP;
GRANT SELECT, INSERT, UPDATE, DELETE ON JOBS        TO GEPER_APP;
GRANT SELECT                        ON JOB_HISTORY  TO GEPER_APP;
GRANT SELECT ON EMPLOYEES_SEQ   TO GEPER_APP;
GRANT SELECT ON DEPARTMENTS_SEQ TO GEPER_APP;
GRANT SELECT ON EMPLOYEES   TO GEPER_LABRO;
GRANT SELECT ON DEPARTMENTS TO GEPER_LABRO;
GRANT SELECT ON JOBS        TO GEPER_LABRO;
EXIT;
EOSQL"
fi

echo "==> [7/8] Instalando OpenJDK 8, usuario sin privilegios 'geper' y servicio systemd..."
if ! command -v java >/dev/null 2>&1 || ! java -version 2>&1 | grep -q '1.8.0'; then
  yum install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel >/dev/null
fi

if ! id -u geper >/dev/null 2>&1; then
  useradd --system --no-create-home --shell /sbin/nologin geper
fi

mkdir -p "$APP_DIR"
cp "${STAGE_DIR}/geper.jar" "${APP_DIR}/geper.jar"
chown -R root:geper "$APP_DIR"
chmod 750 "$APP_DIR"
chmod 640 "${APP_DIR}/geper.jar"

cat >"$APP_ENV_FILE" <<EOF
SERVER_ADDRESS=0.0.0.0
SERVER_PORT=8080
SERVER_TOMCAT_USE_RELATIVE_REDIRECTS=true
GEPER_DB_URL=jdbc:oracle:thin:@//127.0.0.1:1521/${PDB_NAME}
GEPER_DB_USER=GEPER_APP
GEPER_DB_PASSWORD=${ORA_APP_PW}
ENABLE_VULNERABILITY_LABS=false
GEPER_LAB_DB_URL=jdbc:oracle:thin:@//127.0.0.1:1521/${PDB_NAME}
GEPER_LAB_DB_USER=GEPER_LABRO
GEPER_LAB_DB_PASSWORD=${ORA_LABRO_PW}
SPRING_DATASOURCE_HIKARI_INITIALIZATION_FAIL_TIMEOUT=60000
SPRING_DATASOURCE_HIKARI_CONNECTION_TIMEOUT=60000
JAVA_TOOL_OPTIONS=-Doracle.jdbc.timezoneAsRegion=false -Duser.timezone=UTC
EOF
chown root:geper "$APP_ENV_FILE"
chmod 640 "$APP_ENV_FILE"

if systemctl is-active --quiet firewalld; then
  firewall-cmd --permanent --add-port=8080/tcp >/dev/null 2>&1 || true
  firewall-cmd --reload >/dev/null 2>&1 || true
fi

cat >/etc/systemd/system/geper.service <<EOF
[Unit]
Description=GEPER Legacy HR Portal (Java 8 / Spring Boot 2.7 / Oracle 12c R2)
After=network.target oracle-cdb.service
Requires=oracle-cdb.service

[Service]
Type=simple
User=geper
Group=geper
WorkingDirectory=${APP_DIR}
EnvironmentFile=${APP_ENV_FILE}
ExecStart=/usr/bin/java -Xms256m -Xmx512m -jar ${APP_DIR}/geper.jar --server.address=\${SERVER_ADDRESS} --server.port=\${SERVER_PORT}
ExecStartPost=/bin/bash -c 'for i in \$(seq 1 30); do curl -fsS http://127.0.0.1:8080/ >/dev/null 2>&1 && exit 0; sleep 2; done; exit 0'
Restart=always
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable geper.service
systemctl restart geper.service

echo "==> [8/8] Esperando arranque de GEPER en http://127.0.0.1:8080/..."
READY=0
for _ in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:8080/ >/dev/null 2>&1; then
    READY=1
    break
  fi
  sleep 2
done
if [ "$READY" -ne 1 ]; then
  journalctl -u geper.service -n 50 --no-pager >&2
  exit 1
fi

LAB_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8080/lab)
if [ "$LAB_CODE" != "404" ]; then
  echo "ERROR: /lab devolvió ${LAB_CODE} (se esperaba 404 con ENABLE_VULNERABILITY_LABS=false)." >&2
  exit 1
fi

echo "==> Aprovisionamiento de GEPER completado exitosamente (HTTP 200 en /, HTTP 404 en /lab)."
