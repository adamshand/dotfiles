#!/bin/bash

# Written by Adam Shand <adam@shand.net> 5 March 2024
# Simple, no options script to back up all MySQL, PostgreSQL & SQLite databases inside Docker volumes

source "$(dirname $0)/utilities.sh"

umask 077   # root read only
PATH=/sbin:/bin:/usr/sbin:/usr/bin
SQLITE="sqlite3 -batch"
SQLITE_SEARCH_DEPTH=2

BACKUP_BASE="/var/backups/db"
DAYS_TO_KEEP=2
DATESTAMP="$(date +%Y-%m-%d)"
TIMESTAMP="$(date +%H%M)"

DEBUG="yes"
#DEBUG=""

DATABASE_REGEX="(db|mysql|postgres|ldap)"
# EXCLUDE_MOUNT_REGEX="/srv/srv/www /vol/media/moa"
EXCLUDE_MOUNT_REGEX="^(/srv|srv/www|/vol/moa/media|/vol/moa/media/[a-z]*)$"
EXCLUDE_SQLITE_REGEX="^(.*users.*|.*\.bak)$"

if [ "$EUID" -ne 0 ]; then
  print_error "must be run as root"
fi

for cmd in docker sqlite3; do
  if ! command -v $cmd &> /dev/null; then
    print_error "$cmd command, not found"
  fi
done

if [ ! -d "$BACKUP_BASE" ]; then
  if install -o root -g backup -m 0750 -d $BACKUP_BASE; then
   echo "INFO: created $BACKUP_BASE" 1>&2
  else
    echo "error: cannot create $BACKUP_BASE" 1>&2
    exit 1
  fi
fi

test -n "$DEBUG" && echo "DEBUG: $DEBUG" 1>&2


make_backup_dir() {
  local BACKUP_DIR="$1"

  if mkdir -p "$BACKUP_DIR"; then
    test "$DEBUG" && echo "DEBUG CREATING: $BACKUP_DIR"
  else
    print_error "error: cannot create $BACKUP_DIR" 1>&2
  fi
}

find_sqlite_databases() {
  find ${1} -maxdepth ${SQLITE_SEARCH_DEPTH} -exec file {} \; \
    | awk -F: '/SQLite 3.x database/ {print $1}' 
}

backup_sqlite_database() {
  local sqlite_file="$1"
  local slug_raw="${sqlite_file#${mount_src}/}"
  local slug="${slug_raw//\//#}"
  local backup_file="${BACKUP_DIR}/${slug}"

  echo "sqlite .backup: ${sqlite_file} -> ${backup_file}.sqlite.gz"
  $SQLITE $sqlite_file ".backup ${backup_file}.sqlite" && gzip -9qf ${backup_file}.sqlite

  echo "sqlite .dump: ${sqlite_file} -> ${backup_file}.sql.gz"
  $SQLITE $sqlite_file ".dump" | gzip -9 > ${backup_file}.sql.gz
  echo
}

for container in $(docker container ls --format "{{.Names}}"); do
  # remove `.replica#.swarm_id` from end of container name to have stable backup dir
  # note: sed requires \+ to to mean 'one or more' 
  container_short="$( echo $container_raw | sed 's/\.[0-9]\+\.[A-Za-z0-9]\+//g' )"

  print_debug "container: $container"

  if echo $container | grep -iEq "$DATABASE_REGEX"; then
    print_debug "$container matches DATABASE_REGEX $DATABASE_REGEX"
  fi

  BACKUP_DIR="${BACKUP_BASE}/${container_short}/${DATESTAMP}"
  echo "backup_dir: ${BACKUP_DIR}"
  make_backup_dir ${BACKUP_DIR}

  for mount_src in $( docker inspect "$container" --format '{{range .Mounts}}{{println .Source}}{{end}}' ); do
    # echo "echo $mount_src | grep $EXCLUDE_MOUNT_REGEX"
    if echo $mount_src | grep -Eq "$EXCLUDE_MOUNT_REGEX"; then
      print_debug "on ${container}, skipping excluded mount_source: $mount_src"
      continue
    fi

    if [ ! -d "$mount_src" ]; then
      print_debug "on ${container}, skipping file $mount_src"
      continue
    fi

    echo "mount_src: $mount_src"

    for db in $( find_sqlite_databases $mount_src ); do
      if echo $db | grep -Eq "$EXCLUDE_SQLITE_REGEX"; then
        echo "sqlite_db: skipping $db"
        continue
      fi

      echo "sqlite_db: $db"
      backup_sqlite_database $db
    done


  done
  echo
done

