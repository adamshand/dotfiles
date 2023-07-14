#!/bin/bash

MIKROTIK="172.16.1.38 172.16.1.39"
TMPFILE="$(mktemp)"
FOLDER="/Users/adam/Documents/Backups/Mikrotik"
#TODAY="$(date +%Y-%m-%d)"
TODAY="$(date +%a)"
SSH_KEY="~adam/.ssh/id_rsa"

trap 'rm -f ${TMPFILE}; exit 1' 1 2 15

for router in $MIKROTIK; do
  ssh -i $SSH_KEY adam@${router} export > $TMPFILE
  
  if [ -s $TMPFILE ]; then
    mv $TMPFILE ${FOLDER}/${router}-${TODAY}.txt
  fi
done

