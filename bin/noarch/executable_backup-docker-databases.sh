#!/bin/bash

# Written by Adam 24-Sep-20
# Backs up all PostgreSQL, PostGIS, MySQL, MariaDB and Mongo databases
# running within docker containers.

umask 077   # root read only
PATH=/sbin:/bin:/usr/sbin:/usr/bin
RUNBY="$(whoami)"

BACKUP_BASE="/var/backups/db"
DAYS_TO_KEEP=2
DATESTAMP="$(date +%Y-%m-%d)"
TIMESTAMP="$(date +%H%M)"

if [ "$1" == "debug" ]; then
  DEBUG="yes"
fi

if [ "$RUNBY" != "root" ]; then
  echo "error: must be run as root (not $RUNBY)" 1>&2
  exit 1
fi

if [ -x /bin/docker ] || [ -x /usr/bin/docker ]; then
  test $DEBUG && echo "info: docker binary found"
else
  test $DEBUG && echo "info: docker binary not found, exiting …"
  exit 0
fi

# do not backup any database which has test in it's name
# sort containers randomly so if there's an error it doesn't always miss the same containers
CONTAINERS="$(docker ps --format {{.Names}} | grep -Eiv "zabbix-web-nginx-mysql|test" | sort -R | tr '\n' ' ')"

if [ -z "$CONTAINERS" ]; then
  test $DEBUG && echo "info: no containers running, exiting …"
  exit 0
fi

test $DEBUG && echo -e "## ALL CONTAINERS: $CONTAINERS"

setup_backup () {
  echo -e "\n# Container: $container"
  BACKUP_DB_DIR="${BACKUP_BASE}/${container}/${DATESTAMP}"

  if mkdir -p "$BACKUP_DB_DIR"; then
    test $DEBUG && echo "info: making backup directory $BACKUP_DB_DIR"
  else
    echo "error: cannot create $BACKUP_DB_DIR" 1>&2
    exit 1
  fi
}

for container in $CONTAINERS; do
  # MySQL or MariaDB
  if echo "$container" | egrep -qi "db|mysql|maria"; then
    setup_backup

    USERPASS=$(docker exec "$container" sh -c '\
      if [ -n "$MYSQL_ROOT_PASSWORD_FILE" ]; then
        echo "-uroot -p$(cat ${MYSQL_ROOT_PASSWORD_FILE})"
      elif [ -n "$MYSQL_ROOT_PASSWORD" ]; then
        echo "-uroot -p${MYSQL_ROOT_PASSWORD}"
      elif [ "$MYSQL_ALLOW_EMPTY_PASSWORD" = "true" ]; then
        continue
      elif [ -n "$DB_USER" ] && [ -n "$DB_PASSWORD" ]; then
        echo -n "-u${DB_USER} -p${DB_PASSWORD}"
      fi;
    ')
    test $DEBUG && echo "password: $PASSWORD"

    DATABASES=$(docker exec "$container" \
      mysql ${USERPASS} -Bse "show databases;"
    )
    test $DEBUG && echo -e "## DATABASES: $DATABASES"

    for database in $DATABASES; do
      [ "$database" == "information_schema" ] && continue
      [ "$database" == "performance_schema" ] && continue
      [ "$database" == "sys" ] && continue

      # hour and minute appended to support backing up multiple times per day if desired
      BACKUPFILE="${BACKUP_DB_DIR}/${database}-${TIMESTAMP}.sql.gz"
      echo "database: $database -> $BACKUPFILE"

      docker exec "$container" \
        mysqldump --force ${USERPASS} "$database" | gzip > "$BACKUPFILE"
    done

  # PostgreSQL or PostGIS
  elif echo "$container" | grep -Eiq "postgis|postgres"; then
    setup_backup

    DATABASES=$(docker exec "$container" psql -U postgres --tuples-only -P format=unaligned \
      -c "SELECT datname FROM pg_database WHERE NOT datistemplate AND datname <> 'postgres'"
    )
    test $DEBUG && echo -e "## DATABASES: \n$DATABASES"

    for database in $DATABASES; do
      # BACKUPFILE="${BACKUP_DB_DIR}/${database}-${TIMESTAMP}.sql.gz"
      # echo "database: $database -> $BACKUPFILE"
      # docker exec $container pg_dump -U postgres $database | gzip > $BACKUPFILE

      BACKUPFILE="${BACKUP_DB_DIR}/${database}-${TIMESTAMP}.dump"
      echo "database: $database -> $BACKUPFILE"
      docker exec "$container" pg_dump -U postgres --format=c "$database" > "$BACKUPFILE"
    done

  # MongoDB
  elif echo "$container" | grep -Eiq "mongo"; then
    setup_backup

    database="${container//_*}"

    BACKUPFILE="${BACKUP_DB_DIR}/${database}-${TIMESTAMP}.mongo.gz"
    echo "database: $database -> $BACKUPFILE"
    docker exec "$container" mongodump --quiet --archive | gzip > "$BACKUPFILE"

  else
    SKIPPED="$SKIPPED $container"
  fi
done

test $DEBUG && echo -e "\n## Skipped containers: $SKIPPED"

# Delete backups more than $DAYS_TO_KEEP days old
find $BACKUP_BASE -mindepth 1 -maxdepth 2 -mtime +${DAYS_TO_KEEP} -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]" -print0 | xargs --no-run-if-empty -0 rm -rv
