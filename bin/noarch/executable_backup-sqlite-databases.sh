#!/bin/bash

# Written by Adam 23-Feb-2023
# Backup and dumps sqlite database

umask 077   # root read only
PATH=/sbin:/bin:/usr/sbin:/usr/bin
SQLITE="sqlite3 -batch"

#BACKUP_BASE="/tmp/db"
BACKUP_BASE="/var/backups/db"
DAYS_TO_KEEP=2
DATESTAMP="$(date +%Y-%m-%d)"
TIMESTAMP="$(date +%H%M)"

if [ -z "$1" ]; then
  echo "$(basename $0): [SQLITE FILE]..."
fi

if [ "$1" == "debug" ]; then
  DEBUG="yes"
fi

for file in $*; do

  echo -ne "\nfile: $file "
  if [ ! -r $file ]; then
    echo "error: file is not readable or doesn't exist" 1>&2
    continue
  fi

  database=$(ls $file | awk -F/ '/^\/srv/ {print $3}')
  echo "db: $database"
  if [ -z "$database" ]; then
    echo "error: can't detect database name" 1>&2
    continue
  fi

  is_sqlite=$(file $file | grep "SQLite 3.x database,")
  #echo "is_sqlite: $is_sqlite"
  if [ -z "$is_sqlite" ]; then
    echo "error: is not a sqlite3 database" 1>&2
    continue
  fi

  BACKUP_DB_DIR="${BACKUP_BASE}/${database}/${DATESTAMP}"

  if mkdir -p "$BACKUP_DB_DIR"; then
    test $DEBUG && echo "info: making backup directory $BACKUP_DB_DIR"
  else
    echo "error: cannot create $BACKUP_DB_DIR" 1>&2
    exit 1
  fi

  # hour and minute appended to support backing up multiple times per day if desired
  BACKUPFILE="${BACKUP_DB_DIR}/${database}-${TIMESTAMP}"

  echo "backup: $database -> ${BACKUPFILE}.sqlite.gz"
  $SQLITE $file ".backup ${BACKUPFILE}.sqlite" && gzip -qf ${BACKUPFILE}.sqlite

  echo "dump: $database -> ${BACKUPFILE}.sql.gz"
  $SQLITE $file ".dump" | gzip -9 > ${BACKUPFILE}.sql.gz

done

# Delete backups more than $DAYS_TO_KEEP days old
find $BACKUP_BASE -mindepth 1 -maxdepth 2 -mtime +${DAYS_TO_KEEP} -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]" -print0 | xargs --no-run-if-empty -0 rm -rv

echo -e "\n##########\n"
tree --du -sh /var/backups/db/
