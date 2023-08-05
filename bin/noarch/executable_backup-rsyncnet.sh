#!/bin/bash
# Written by Adam August 2020
# Runs daily as root and backs up folders to rsync.net

PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin
HOSTNAME="$(hostname -s | awk '{print tolower($0)}')"
RUNAS="$(whoami)"
RSYNC_HOST="123456@prio.ch-s011.rsync.net"
RSYNC_OPTS="-avz --delete-excluded --ignore-errors --exclude-from=/usr/local/etc/rsyncnet-exclude.txt"
# /etc/ should be the last thing sync'd so the timestamp on rsyncnet.state can be used to indicate complete backup
RSYNC_SRC="/usr/local /var/backups /var/spool /etc"
STATEFILE="/etc/rsyncnet.state"

if [ "$RUNAS" != "root" ]; then
  echo "Error: must be run as root (instead of $RUNAS)." 1>&2
  exit 1
fi

unset DEBUG
if [ "$1" == "debug" ]; then
  DEBUG="yes"
fi

# Make sure there are no overlapping instances due to long running jobs
LOCKFILE="/etc/rsyncnet.lock"
if [ -f ${LOCKFILE} ]; then
  echo "error: lockfile ${LOCKFILE} already exists, exiting …" 1>&2
  exit 1
else
  touch ${LOCKFILE}
  trap 'test $DEBUG && echo "info: removing $LOCKFILE"; rm -f ${LOCKFILE}; exit 0' 1 2 15
fi

if [ "$1" == "check" ]; then
  if [ ! -f /root/.ssh/id_rsa -o ! -f /root/.ssh/id_rsa.pub ]; then
    echo "Missing ~root/.ssh/ id_rsa or id_rsa.pub"
  fi
  echo "ls -l host/${HOSTNAME}/" | sftp ${RSYNC_HOST}
  rm $LOCKFILE
  exit 0
fi

if [ "$1" == "setup" ]; then
  if [ ! -f /root/.ssh/id_rsa -o ! -f /root/.ssh/id_rsa.pub ]; then
    ssh-keygen -f /root/.ssh/id_rsa -N ""
  fi
  echo -e "\nPushing ssh key to ${RSYNC_HOST} …"
  cat /root/.ssh/id_rsa.pub | /usr/bin/ssh ${RSYNC_HOST} 'dd of=.ssh/authorized_keys oflag=append conv=notrunc'

  echo -e "mkdir host/${HOSTNAME}\nmkdir host/${HOSTNAME}/hello" | sftp ${RSYNC_HOST}
  rm $LOCKFILE
  exit 0
fi

## !!! make sure directory added to RSYNC_SRC line DOES NOT have a trailing slash
if [ -d /home/docker/ ]; then
  RSYNC_SRC="/home/docker $RSYNC_SRC"
fi
  
if [ -d /media ]; then
  RSYNC_SRC="/media $RSYNC_SRC"
fi

echo -e "## Starting at $(date) \n## Backing up ${RSYNC_SRC} from ${HOSTNAME} \n" | tee $STATEFILE

if [ -z "$DEBUG" ]; then
  # wait for a random time up to 30 minutes
  MINUTES="$(( $RANDOM % 30 ))"
  echo "## Sleeping for $MINUTES minutes"
  sleep ${MINUTES}m
fi

rsync ${RSYNC_OPTS} ${RSYNC_SRC} ${RSYNC_HOST}:host/${HOSTNAME}/ | tee -a $STATEFILE

test $DEBUG && echo "info: removing $LOCKFILE"
rm $LOCKFILE

echo -e "\n## Finished at $(date)" | tee -a $STATEFILE
