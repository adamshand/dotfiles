#!/bin/bash

MIKROTIK="172.16.1.38 172.16.1.39"
FOLDER="/Users/adam/Documents/Backups/Mikrotik"
#TODAY="$(date +%Y-%m-%d)"
TODAY="$(date +%a)"
SSH_KEY="~adam/.ssh/id_rsa"

for router in $MIKROTIK; do
  ssh -v -i $SSH_KEY adam@${router} export > ${FOLDER}/${router}-${TODAY}.txt
done
