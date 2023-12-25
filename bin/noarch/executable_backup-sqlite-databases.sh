#!/bin/bash

# Backup and dumps sqlite databases, written by <adam@shand.net>
# - 23-Feb-2023 initial version
# - 25-Dec-2023 updated for CapRover

# TODO
# - update APPLICATIONS - file with leading / means not in Docker Volume
#   eg. memos|/srv/app/memos_prod.db

APPLICATIONS="
  dockge|dockge.db
  databag|databag.db
  gonic|gonic.db
  linkding|db.sqlite3
  lldap|users.db
  lychee|database.sqlite
  memos|memos_prod.db
  n8n|database.sqlite
  pigallery2|sqlite.db
  pocketbase|pb_data/data.db
  pocketbase|pb_data/logs.db
  silverbullet|data.db
  synapse|homeserver.db
  uptime-kuma|kuma.db
  vaultwarden|db.sqlite3
"

umask 077   # root read only
PATH=/sbin:/bin:/usr/sbin:/usr/bin
SQLITE="sqlite3 -batch"

BACKUP_BASE="/var/backups/db"
DAYS_TO_KEEP=2
DATESTAMP="$(date +%Y-%m-%d)"
TIMESTAMP="$(date +%H%M)"

# if [ -z "$1" ]; then
#   echo "$(basename $0): [SQLITE FILE]..."
# fi

if [ $EUID -ne 0 ]; then
  echo "error: must be run as root"
  exit 1
fi

if [ "$1" == "debug" ]; then
  DEBUG="yes"
  echo "DEBUG: on"
fi

for volume in $(docker volume ls -q); do

  for application in $APPLICATIONS; do
    APP=${application%%|*}
    DB=${application#*|}
  
    if [[ ! "$volume" == *"$APP"* ]]; then
      continue
    fi

    VOL_PATH=$(docker volume inspect $volume | awk -F\" '/Mountpoint/ {print $4}')
    DB_FILE=${VOL_PATH}/$DB

    if [ ! -r "$DB_FILE" ]; then
      echo -e "error: file doesn't exist or isn't readable.\n       $DB_FILE\n" 1>&2
      continue
    fi

    if [[ ! $(file $DB_FILE) == *"SQLite 3.x"* ]]; then
      echo -e "error: not an SQLite database.\n       $DB_FILE\n" 1>&2
      continue
    fi

    test $DEBUG && echo -e "\nDEBUG: VOLUME: $volume APP: $APP DB: $DB"
    
    BACKUP_DIR="${BACKUP_BASE}/${APP}/${DATESTAMP}"
    if mkdir -p "$BACKUP_DIR"; then
      test $DEBUG && echo "DEBUG: creating $BACKUP_DIR"
    else
      echo "error: cannot create $BACKUP_DIR" 1>&2
      exit 1
    fi

    # hour and minute appended to support backing up multiple times per day
    # ${DB//[.\/]/_} replaces . and / with _ in $DB
    BACKUP_FILE="${BACKUP_DIR}/${APP}-${DB//[.\/]/-}.${TIMESTAMP}"

    echo "sqlite .backup: ${APP}|${DB} -> ${BACKUP_FILE}.sqlite.gz"
    $SQLITE $DB_FILE ".backup ${BACKUP_FILE}.sqlite" && gzip -9qf ${BACKUP_FILE}.sqlite

    echo "sqlite .dump: ${APP}|${DB} -> ${BACKUP_FILE}.sql.gz"
    $SQLITE $DB_FILE ".dump" | gzip -9 > ${BACKUP_FILE}.sql.gz

    echo
  done  # end application loop
done    # end docker volume loop

# Delete backups more than $DAYS_TO_KEEP days old
find $BACKUP_BASE -mindepth 1 -maxdepth 2 -mtime +${DAYS_TO_KEEP} -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]" -print0 | xargs --no-run-if-empty -0 rm -rv

echo -e "\n##########\n"
tree --du -sh /var/backups/db/
