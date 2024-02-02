#!/bin/bash

# Backup and dumps sqlite databases, written by <adam@shand.net>
# - 23 Feb 2023 initial version
# - 25 Dec 2023 updated to automatically find SQLite databases in Docker Volumes
# - 18 Jan 2024 will now automatically create $BACKUPBASE if required
# - 25 Jan 2024 added check for sqlite3
# -  2 Feb 2024 automatic debug mode if recently modified
#
# NOTES
# - backs up all SQLite files found in the top two levels of a Docker Volume
# - skips any files matching *deleteme*

# TODO
# - add ability to back up arbitrary SQLite files ?

umask 077   # root read only
PATH=/sbin:/bin:/usr/sbin:/usr/bin
SQLITE="sqlite3 -batch"

BACKUP_BASE="/var/backups/db"
DAYS_TO_KEEP=2
DATESTAMP="$(date +%Y-%m-%d)"
TIMESTAMP="$(date +%H%M)"

if [ "$EUID" -ne 0 ]; then
  echo "error: must be run as root"
  exit 1
fi

if ! which sqlite3 > /dev/null; then
  echo "error: please install sqlite command"
  exit 1
fi

if [ "$1" == "debug" ]; then
  DEBUG="on"
else
  source ./utilities.sh
  DEBUG="$(check_recently_modified)"
fi

test -n "$DEBUG" && echo "DEBUG: $DEBUG" 1>&2

if [ ! -d "$BACKUP_BASE" ]; then
  if install -o root -g backup -m 0750 -d $BACKUP_BASE; then
   echo "INFO: created $BACKUP_BASE" 1>&2
  else
    echo "error: cannot create $BACKUP_BASE" 1>&2
    exit 1
  fi
fi

for volume in $(docker volume ls -q); do
    echo -e "\n## VOLUME: $volume"

    BACKUP_DIR="${BACKUP_BASE}/${volume}/${DATESTAMP}"
    test "$DEBUG" && echo "DEBUG BACKUP_DIR: $BACKUP_DIR"

    MOUNTPOINT=$(docker volume inspect $volume | awk -F\" '/Mountpoint/ {print $4}')
    test "$DEBUG" && echo "DEBUG MOUNTPOINT: $MOUNTPOINT"

    SQLITE_FILES=$(
      sudo find ${MOUNTPOINT} -maxdepth 2 -exec file {} \; \
        | awk -F: '/SQLite 3.x database/ {print $1}'
    )

    for db_file in $SQLITE_FILES; do
      test "$DEBUG" && echo "DEBUG FILE: $db_file"

      if [[ "$db_file" == *"deleteme"* ]]; then
        continue
      fi

      if mkdir -p "$BACKUP_DIR"; then
        test "$DEBUG" && echo "DEBUG CREATING: $BACKUP_DIR"
      else
        echo "error: cannot create $BACKUP_DIR" 1>&2
        exit 1
      fi

      # remove MOUNTPOINT prefix from db_file
      SLUG=${db_file#${MOUNTPOINT}/}
      # replace . and / with -
      SLUG=${SLUG//[.\/]/-}
      test "$DEBUG" && echo "DEBUG SLUG: $SLUG"

      # hour and minute appended to support backing up multiple times per day
      BACKUP_FILE="${BACKUP_DIR}/${SLUG}-${TIMESTAMP}"
      test "$DEBUG" && echo "DEBUG BACKUP_FILE: $BACKUP_FILE"

      echo -e "\nsqlite .backup: ${volume}|${SLUG} -> ${BACKUP_FILE}.sqlite.gz"
      $SQLITE $db_file ".backup ${BACKUP_FILE}.sqlite" && gzip -9qf ${BACKUP_FILE}.sqlite

      echo "sqlite .dump: ${volume}|${SLUG} -> ${BACKUP_FILE}.sql.gz"
      $SQLITE $db_file ".dump" | gzip -9 > ${BACKUP_FILE}.sql.gz
    done

done    # end docker volume loop

# Delete backups more than $DAYS_TO_KEEP days old
find $BACKUP_BASE -mindepth 1 -maxdepth 2 -mtime +${DAYS_TO_KEEP} -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]" -print0 | xargs --no-run-if-empty -0 rm -rv

echo -e "\n##########\n"
tree --du -sh /var/backups/db/
