#!/bin/bash

# Exports config of listed Mikrotik devices to a folder.
# Preserves 6 Daily, 4 Weekly & 12 Monthly backups for each device.

# Written by Adam Shand <adam@shand.net> on 26 May 2023

# Updates:
#   10 Feb 24 - Fix broken paths when running from cron
#             - Keep daily, weekly & monthly backups (overwrite new, instead of deleting old)

# IMPORTANT: On macOS you must give full disk access to `/usr/bin/cron` or change $FOLDER
FOLDER="${HOME}/Documents/Backups/Mikrotik"
SSH_OPTIONS="-i ${HOME}/.ssh/id_rsa -o BatchMode=yes"
MIKROTIKS="172.16.1.38 172.16.1.39"

if [ ! -d "${FOLDER}" ]; then
  echo "info: making folder: ${FOLDER}" >&2
  mkdir -p "${FOLDER}"
fi

DOW=$(date +%u)          # Day   of week  (1-7)
DOM=$(date +%d)          # Day   of month (01-31)
WOY=$(date +%V)          # Week  of year  (01-52)
WOM=$(( 10#${WOY} % 4 )) # Week  of month (eg. 1-4)   (10# to avoid octal from 0 padding)
MOY=$(date +%m)          # Month of year  (01-12)

# echo "info: DOW=${DOW} DOM=${DOM} WOY=${WOY} WOM=${WOM} MOY=${MOY}"

if [ "$DOM" == 1 ]; then
  SUFFIX="monthly-${MOY}"
  echo "info: $SUFFIX"
elif [ "$DOW" == 7 ]; then
  SUFFIX="weekly-${WOM}"
  echo "info: $SUFFIX"
else
  SUFFIX="daily-${DOW}"
  echo "info: $SUFFIX"
fi

for mikrotik in $MIKROTIKS; do
  FILE="${FOLDER}/${mikrotik}-${SUFFIX}.txt"
  echo "export ${mikrotik} config to ${FILE}"
  ssh ${SSH_OPTIONS} adam@${mikrotik} export > ${FILE}
done
