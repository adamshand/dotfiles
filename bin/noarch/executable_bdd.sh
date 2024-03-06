#!/bin/bash

# Written by Adam Shand <adam@shand.net> 5 March 2024
# Simple, no options script to back up all MySQL, PostgreSQL & SQLite databases inside Docker volumes

source "$(dirname $0)/utilities.sh"

umask 077   # root read only
PATH=/sbin:/bin:/usr/sbin:/usr/bin
SQLITE="sqlite3 -batch"
SQLITE_SEARCH_DEPTH=2

BACKUP_BASE="/var/backups/db"
BACKUP_BASE="/tmp/backups-db"
DAYS_TO_KEEP=2
DATESTAMP="$(date +%Y-%m-%d)"
TIMESTAMP="$(date +%H%M)"

DEBUG="yes"
#DEBUG=""

DATABASE_REGEX="(db|mysql|mariadb|postgres|ldap)"
# EXCLUDE_MOUNT_REGEX="/srv/srv/www /vol/media/moa"
EXCLUDE_MOUNT_REGEX="^(/srv|srv/www|/vol/moa/media|/vol/moa/media/[a-z]*)$"
EXCLUDE_SQLITE_REGEX="^(.*users.*|.*\.bak|.*\.old)$"

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
   print_debug "created $BACKUP_BASE" 1>&2
  else
    print_error "cannot create $BACKUP_BASE" 1>&2
  fi
fi

make_backup_dest() {
  local folder="$1"

  if mkdir -p -m 700 "$folder"; then
    echo "backup_dest: $folder"
  else
    print_error "cannot create $folder" 1>&2
  fi
}

## BACKUP POSTGRESQL

## BACKUP SQLITE DATABASES
sqlite_backup_container() {
  # Search every container mount for SQLite files 
  for mount in $( docker inspect "$container" --format '{{range .Mounts}}{{println .Source}}{{end}}' ); do
    if echo $mount | grep -Eq "$EXCLUDE_MOUNT_REGEX"; then
      echo "## mount: $mount (skipping, matches ${EXCLUDE_MOUNT_REGEX})"
      continue
    fi

    if [ ! -d "$mount" ]; then
      echo "## mount: $mount (skipping file)"
      continue
    fi

    echo "## mount: $mount"

    # for db in $( sqlite_find  $mount ); do
    for db in $( find $mount -maxdepth ${SQLITE_SEARCH_DEPTH} -exec file {} \; | awk -F: '/SQLite 3.x database/ {print $1}' ); do
      if echo $db | grep -Eq "$EXCLUDE_SQLITE_REGEX"; then
        echo "sqlite_file: $db (skipping, matches ${EXCLUDE_SQLITE_REGEX})"
        continue
      fi

      echo "# sqlite_file: $db"
      sqlite_backup_file $db
    done
  done
}

sqlite_backup_file() {
  local file_src="$1"
  local slug_raw="${file_src#${mount}/}"
  local slug="${slug_raw//\//#}"
  
  # remove `.replica#.swarm_id` from end of container name to have stable backup dir
  local backup_dest="${BACKUP_BASE}/${container//\.[0-9]*\.[A-Za-z0-9]*/}/${DATESTAMP}"
  make_backup_dest ${backup_dest}

  local file_dest="${backup_dest}/${slug}-${TIMESTAMP}"

  # TODO: some kind of retry on locking errors?
  # eg. sql error: database is locked (5)

  echo "sqlite .backup: ${file_src} -> ${file_dest}.sqlite.gz"
  $SQLITE $file_src ".backup ${file_dest}.sqlite" && gzip -9qf ${file_dest}.sqlite

  echo "sqlite .dump: ${file_src} -> ${file_dest}.sql.gz"
  $SQLITE $file_src ".dump" | gzip -9 > ${file_dest}.sql.gz
}

## BEGIN MAIN
test -n "$DEBUG" && echo "DEBUG: $DEBUG" 1>&2

for container in $(docker container ls --format "{{.Names}}"); do
  echo -e "\n### container: $container"

  # Match MySQL, MariaDB or PostgreSQL
  if echo $container | grep -iEq "$DATABASE_REGEX"; then
    print_debug "$container matches DATABASE_REGEX $DATABASE_REGEX"
    
  else
    sqlite_backup_container
  fi
done

# Delete backups more than $DAYS_TO_KEEP days old
echo -e "\n## DELETING OLD BACKUPS"
find "$BACKUP_BASE" -mindepth 1 -maxdepth 2 -mtime +${DAYS_TO_KEEP} -name "[0-9]{4}-[0-9]{2}-[0-9]{2}" -print -delete

# Delete empty directories (but not BACKUP_BASE)
echo -e "\n## DELETING EMPTY FOLDERS"
find "$BACKUP_BASE" -mindepth 1 -type d -empty -print -delete

echo -e "\n## CURRENT BACKUPS IN ${BACKUP_BASE}\n"
tree --du -sh "$BACKUP_BASE"

##############################
### delete ...
deleteme_sqlite_find() {
  result=$( 
    find ${1} -maxdepth ${SQLITE_SEARCH_DEPTH} -exec file {} \; | awk -F: '/SQLite 3.x database/ {print $1}' 
  )

  if [ -z "$result" ]; then
    return 1
  else
    echo "$result"
  fi
}

container_short="$( echo $container | sed 's/\.[0-9]\+\.[A-Za-z0-9]\+//g' )"
