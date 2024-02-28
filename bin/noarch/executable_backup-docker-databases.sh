#!/bin/bash

# Written by Adam 24-Sep-20
# Backs up all PostgreSQL, PostGIS, MySQL, MariaDB and Mongo databases
# running within docker containers.
#
# TODO
# - automatically run in debug mode if file has been modified in last 48 hours
# - fix constanting changing backup dirs due to swarm .1.xxx names

umask 077   # root read only
PATH=/sbin:/bin:/usr/sbin:/usr/bin
RUNBY="$(whoami)"

BACKUP_BASE="/var/backups/db"
DAYS_TO_KEEP=2
DATESTAMP="$(date +%Y-%m-%d)"
TIMESTAMP="$(date +%H%M)"

SKIP_CONTAINER_REGEX="captain-[A-z]|test"

if [ "$1" == "debug" ]; then
  DEBUG="yes"
fi

if [ "$RUNBY" != "root" ]; then
  echo "error: must be run as root (not $RUNBY)" 1>&2
  exit 1
fi

if [ -x /bin/docker ] || [ -x /usr/bin/docker ]; then
  test "$DEBUG" && echo "info: docker binary found"
else
  test "$DEBUG" && echo "info: docker binary not found, exiting …"
  exit 0
fi

CONTAINERS="$( docker ps --format {{.Names}} | grep -Eiv "${SKIP_CONTAINER_REGEX}" )"
CONTAINERS="$( echo $CONTAINERS | sort -R | tr '\n' ' ' )"

if [ -z "$CONTAINERS" ]; then
  test "$DEBUG" && echo "info: no containers running, exiting …"
  exit 0
fi

test "$DEBUG" && echo -e "## ALL CONTAINERS: $CONTAINERS"

setup_backup () {
  if docker info | grep --silent "^ Swarm: active"; then
    # remove `.replica#.swarm_id` from end of container name to have stable backup dir
    # note: sed requires \+ to to mean 'one or more' 
    backup_container="$( echo $container | sed 's/\.[0-9]\+\.[A-Za-z0-9]\+//g' )"
  fi

  echo -e "\n# Container: $container"
  BACKUP_DB_DIR="${BACKUP_BASE}/${backup_container}/${DATESTAMP}"

  if mkdir -p "$BACKUP_DB_DIR"; then
    test "$DEBUG" && echo "info: making backup directory $BACKUP_DB_DIR"
  else
    echo "error: cannot create $BACKUP_DB_DIR" 1>&2
    exit 1
  fi
}

for container in $CONTAINERS; do
  if echo "$container" | egrep -qi "db|mysql|maria"; then
    # MySQL or MariaDB
    setup_backup

    MY_ROOT_PASSWORD="$( docker inspect "$container" | jq -r '.[0].Config.Env[] | select(startswith("MYSQL_ROOT_PASSWORD=")) | split("=")[1]' )"
    # MY_DB="$( docker inspect "$container" | jq -r '.[0].Config.Env[] | select(startswith("MYSQL_DATABASE=")) | split("=")[1]' )"
    # MY_USER="$( docker inspect "$container" | jq -r '.[0].Config.Env[] | select(startswith("MYSQL_USER=")) | split("=")[1]' )"
    # MY_PASS="$( docker inspect "$container" | jq -r '.[0].Config.Env[] | select(startswith("MYSQL_PASSWORD=")) | split("=")[1]' )"

    # test "$DEBUG" && echo "MY ROOT_PASS: $MY_ROOT_PASSWORD"

    # Using MYSQL_PWD stops "Using a password on the command line interface can be insecure"
    DATABASES=$( docker exec -e MYSQL_PWD="$MY_ROOT_PASSWORD" "$container" \
      mysql -uroot -Bse "show databases;" 
    )
    test "$DEBUG" && echo "## DATABASES: $DATABASES"
    
    for database in $DATABASES; do
      [ "$database" == "information_schema" ] && continue
      [ "$database" == "performance_schema" ] && continue
      [ "$database" == "sys" ] && continue

      # hour and minute appended to support backing up multiple times per day if desired
      BACKUPFILE="${BACKUP_DB_DIR}/${database}-${TIMESTAMP}.sql.gz"
      echo "database: $database -> $BACKUPFILE"

      docker exec -e MYSQL_PWD="$MY_ROOT_PASSWORD" "$container" \
        mysqldump --force -uroot "$database" \
        | gzip > "$BACKUPFILE"
    done

  elif echo "$container" | grep -Eiq "postgis|postgres"; then
    # PostgreSQL or PostGIS
    setup_backup

    PG_USER="$( docker inspect "$container" | jq -r '.[0].Config.Env[] | select(startswith("POSTGRES_USER=")) | split("=")[1]' )"
    # PG_PASS="$( docker inspect "$container" | jq -r '.[0].Config.Env[] | select(startswith("POSTGRES_PASSWORD=")) | split("=")[1]' )"
    # PG_DB="$( docker inspect "$container" | jq -r '.[0].Config.Env[] | select(startswith("POSTGRES_DB=")) | split("=")[1]' )"
    
    test "$DEBUG" && echo "PG USER: $PG_USER"

    # Not sure why, but password doesn't seem to be required.

    DATABASES=$(docker exec "$container" psql -U $PG_USER --tuples-only -P format=unaligned \
      -c "SELECT datname FROM pg_database WHERE NOT datistemplate AND datname <> 'postgres'"
    )
    test "$DEBUG" && echo -e "## DATABASES: \n$DATABASES"


    for database in $DATABASES; do
      # BACKUPFILE="${BACKUP_DB_DIR}/${database}-${TIMESTAMP}.sql.gz"
      # echo "database: $database -> $BACKUPFILE"
      # docker exec $container pg_dump -U postgres $database | gzip > $BACKUPFILE

      BACKUPFILE="${BACKUP_DB_DIR}/${database}-${TIMESTAMP}.dump"
      echo "database: $database -> $BACKUPFILE"
      docker exec "$container" pg_dump -U "$PG_USER" --format=c "$database" > "$BACKUPFILE"
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

test "$DEBUG" && echo -e "\n## Skipped containers: $SKIPPED"

# Delete backups more than $DAYS_TO_KEEP days old
find "$BACKUP_BASE" -mindepth 1 -maxdepth 2 -mtime +${DAYS_TO_KEEP} -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]" -print0 | xargs --no-run-if-empty -0 rm -rv

# delete empty container directories
rmdir --ignore-fail-on-non-empty -pv ${BACKUP_BASE}/*/*

echo -e "\n##########\n"
tree --du -sh "$BACKUP_BASE"

#     USERPASS=$(docker exec "$container" sh -c '\
#       if [ -n "$MYSQL_ROOT_PASSWORD_FILE" ]; then
#         echo "-uroot -p$(cat ${MYSQL_ROOT_PASSWORD_FILE})"
#       elif [ -n "$MYSQL_ROOT_PASSWORD" ]; then
#         echo "-uroot -p${MYSQL_ROOT_PASSWORD}"
#       elif [ "$MYSQL_ALLOW_EMPTY_PASSWORD" = "true" ]; then
#         continue
#       elif [ -n "$DB_USER" ] && [ -n "$DB_PASSWORD" ]; then
#         echo -n "-u${DB_USER} -p${DB_PASSWORD}"
#       fi;
#     ')
#     test "$DEBUG" && echo "password: $PASSWORD"
