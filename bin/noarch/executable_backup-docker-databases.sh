#!/bin/bash

# Written by Adam Shand <adam@shand.net> 5 March 2024
# Simple, no options script to back up all MySQL, PostgreSQL & SQLite databases inside Docker volumes

source "$(dirname $0)/utilities.sh"

umask 077   # root read only
PATH=/sbin:/bin:/usr/sbin:/usr/bin
SQLITE="sqlite3 -batch"
SQLITE_SEARCH_DEPTH=2

BACKUP_BASE="/var/backups/db"
DAYS_TO_KEEP=3
DATESTAMP="$(date +%Y-%m-%d)"
TIMESTAMP="$(date +%H%M)"
BACKUP_GROUP="staff"

DEBUG=""
DEBUG="yes"

DATABASE_REGEX="(db|mysql|mariadb|postgres)"
EXCLUDE_MOUNT_REGEX="^(/srv|srv/www|/vol/moa/media(/[a-z].*)?)$"
EXCLUDE_SQLITE_REGEX="^(.*users.*|.*\.bak|.*\.old)$"

if [ "$EUID" -ne 0 ]; then
  print_error "must be run as root"
fi

for cmd in docker install sqlite3; do
  if ! command -v $cmd &> /dev/null; then
    print_error "$cmd command, not found"
  fi
done

make_backup_dest() {
  local folder="$1"

  if ! install -o root -g "$BACKUP_GROUP" -m 2750 -d $folder; then
    print_error "cannot create $folder" 1>&2
  fi
}

cleanup_backups() {
  # Delete backups more than $DAYS_TO_KEEP old
  echo -e "\n## DELETING BACKUPS OLDER THAN ${DAYS_TO_KEEP} DAYS"
  find /var/backups/db/ -mindepth 1 -maxdepth 3 -mtime +${DAYS_TO_KEEP} -regextype posix-extended -regex '.*/[0-9]{4}-[0-9]{2}-[0-9]{2}/.*' -print -delete
  # Delete empty directories (but not BACKUP_BASE)
  echo -e "\n## DELETING EMPTY FOLDERS"
  find "$BACKUP_BASE" -mindepth 1 -type d -empty -print -delete

  echo -e "\n## CURRENT BACKUPS: ${BACKUP_BASE}\n"
  tree --du -sh "$BACKUP_BASE"
}

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
  local slug="sqlite-${slug_raw//\//#}"

  # remove `.replica#.swarm_id` from end of container name to have stable backup dir
  local backup_dest="${BACKUP_BASE}/${CONTAINER_SHORT}/${DATESTAMP}"
  make_backup_dest ${backup_dest}
  local file_dest="${backup_dest}/${slug}-${TIMESTAMP}"

  # local backup_file="${backup_dest}/${slug}-${TIMESTAMP}.sqlite"
  # echo "backup: ${backup_file}"
  # $SQLITE $file_src ".backup ${backup_file}" && gzip -9qf "${backup_file}"

  local backup_file="${backup_dest}/${slug}-${TIMESTAMP}.sql.gz"
  echo "dump: ${backup_file}"
  $SQLITE $file_src ".dump" | gzip -9 > "${backup_file}"
}

postgres_backup_container() {
  local username=$( docker inspect "$container" | jq -r '.[0].Config.Env[] | select(startswith("POSTGRES_USER=")) | split("=")[1]' )
  local password=$( docker inspect "$container" | jq -r '.[0].Config.Env[] | select(startswith("POSTGRES_PASSWORD=")) | split("=")[1]' )

  if [ -z "$username" ] || [ -z "$password" ]; then
    echo "skipping: username \"${username}\" or password \"${password}\" not found"
    return
  fi

  DATABASES=$( docker exec "$container" psql -U "$username" --tuples-only -P format=unaligned -c "SELECT datname FROM pg_database WHERE NOT datistemplate AND datname <> 'postgres'" )

  for database in $DATABASES; do
    echo "# database: $database (user: $username password: $password)"

    local backup_dest="${BACKUP_BASE}/${CONTAINER_SHORT}/${DATESTAMP}"
    make_backup_dest ${backup_dest}

    local backup_file="${backup_dest}/${database}-${TIMESTAMP}.sql.gz"
    echo "pg_dump: $backup_file"
    docker exec "$container" pg_dump -U "$username" "$database" | gzip > $backup_file

    # local backup_file="${backup_dest}/${database}-${TIMESTAMP}.dump"
    # echo "pg_dump: $backup_file"
    # docker exec "$container" pg_dump -U "$username" --format=c "$database" > "${backup_file}"
  done
}

mysql_backup_container() {
  local password=$( docker inspect "$container" | jq -r '.[0].Config.Env[] | select(startswith("MYSQL_ROOT_PASSWORD=")) | split("=")[1]' )

  if [ -z "$password" ]; then
    echo "skipping: password \"${password}\" not found"
    return
  fi

  # Using MYSQL_PWD stops "Using a password on the command line interface can be insecure" warning messages in cron
  DATABASES=$( docker exec -e MYSQL_PWD="$password" "$container" mysql -uroot -Bse "show databases;" )

  for database in $DATABASES; do
    [ "$database" == "information_schema" ] && continue
    [ "$database" == "performance_schema" ] && continue
    [ "$database" == "sys" ] && continue

    echo "# database: $database (user: $username password: $password)"

    local backup_dest="${BACKUP_BASE}/${CONTAINER_SHORT}/${DATESTAMP}"
    make_backup_dest ${backup_dest}

    local backup_file="${backup_dest}/${database}-${TIMESTAMP}.sql.gz"
    echo "mysqldump: $backup_file"

    docker exec -e MYSQL_PWD="$password" "$container" mysqldump --force -uroot "$database" | gzip > "$backup_file"
  done
}

## MAIN
test -n "$DEBUG" && echo "DEBUG: $DEBUG" 1>&2

if [ ! -d "$BACKUP_BASE" ]; then
  if ! install -o root -g "$BACKUP_GROUP" -m 2750 -d $BACKUP_BASE; then
    print_error "cannot create $BACKUP_BASE" 1>&2
  fi
fi

docker ps --format "{{.Names}} {{.Image}}" | while read container image; do
  CONTAINER_SHORT=${container//\.[0-9]*\.[A-Za-z0-9]*/}
  IMAGE=${image%%:*}
  echo -e "\n### container: $CONTAINER_SHORT (${container}) image: ${IMAGE}"

  if echo $IMAGE | grep -iEq "postgis|postgres"; then
    postgres_backup_container
  elif echo $IMAGE | grep -iEq "mariadb|mysql"; then
    mysql_backup_container
  else
    sqlite_backup_container
  fi
done

cleanup_backups

# TODO: check_backups - every container folder should have a backup for today
