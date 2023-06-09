#!/bin/bash

# Written by Adam Shand <adam@shand.net> 24 Mar 2023
# Inspired by: https://gist.github.com/mikroskeem/8cd3492ce2aa6699c2fa9db3545a58f1#file-setup_sshfp-sh

# TIPS
# - if ssh host and dns zone are the same, prefix ssh server hostname with a dot (eg. .example.nz)
# - add the below to your ~/.ssh/config:
#
#   Host *
#     StrictHostKeyChecking accept-new
#     VerifyHostKeyDNS yes

# Use global api key or create a restricted token: https://dash.cloudflare.com/profile/api-tokens

if [ -r ~/.env ] && egrep -q "^CF_API_TOKEN=" ~/.env; then
  export CF_API_TOKEN=$(awk -F= '/^CF_API_TOKEN=/{print $2}' ~/.env)
else 
  echo "error: CF_API_TOKEN not found in ~/.env"
  exit 1
fi

DNS_ZONE=$(echo $1 | sed 's/^[a-z0-9-]*.//')
SSH_HOST=$(echo $1 | sed 's/^\.//')
PORT=22

if [ -n "$2" ]; then
 PORT="$2"
fi

if [ $# -lt 1 ] || [ "$1" = "help" ] || [ "$1" = "--help" ]; then
  echo "error: must provide ssh server hostname and optional port"
  echo "usage: `basename $0` <hostname> [port]"
  echo
  exit 1
fi

if ! command -v flarectl &> /dev/null; then
  echo "error: requires flarectl cli: https://github.com/cloudflare/cloudflare-go/tree/master/cmd/flarectl"
  echo 
  exit 1
fi

if ! command -v http &> /dev/null; then
  echo "error: requires httpie: https://httpie.io/"
  echo 
  exit 1
fi

SSH_KEYS=$(ssh-keyscan -p $PORT -D $SSH_HOST 2>&1 | grep SSHFP)
if [ $? -eq 1 ]; then
  echo "error: no ssh server keys found at ${SSH_HOST}:${PORT}"
  echo
  exit 1
else 
  echo "info: found ssh keys at ${SSH_HOST}:${PORT}"
fi

CF_ZONE_ID=$(flarectl zone info $DNS_ZONE | grep $DNS_ZONE | awk '{print $1}')
if [ -z "$CF_ZONE_ID" ]; then
  echo "error: zone \"$DNS_ZONE\" doesn't exist on your cloudflare account or your api token is incorrect"
  echo 
  exit 1
fi

OLD_SSHFP=$(flarectl dns list --zone ${DNS_ZONE} | grep "SSHFP | ${SSH_HOST}" | awk '{print $1}')
if [ -n "$OLD_SSHFP" ]; then
  for record in $OLD_SSHFP; do
    echo "deleting existing sshfp record for $SSH_HOST ($record)"
    flarectl dns delete --zone ${DNS_ZONE} --id $record
  done
else 
  echo "info: no existing sshfp records for $SSH_HOST"
fi

IFS=$'\n' 
for key in $SSH_KEYS; do
  ALGORITHM=$(echo $key | awk '{print $4}')
  TYPE=$(echo $key | awk '{print $5}')
  FINGERPRINT=$(echo $key | awk '{print $6}')

  #echo "debug: algorithm: $ALGORITHM type: $TYPE FINGERPRINT: $FINGERPRINT"
  PAYLOAD='{
    "name": "'${SSH_HOST}'",
    "type": "SSHFP",
    "comment": "added by '$(basename $0)'", 
    "data": { 
      "algorithm": "'${ALGORITHM}'", 
      "type": "'${TYPE}'", 
      "fingerprint": "'${FINGERPRINT}'" 
    }
  }' 

  # FIXME: Create sshfp records with flarectl?
  echo $PAYLOAD | \
    http --quiet --body -A bearer -a ${CF_API_TOKEN} \
    https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records && \
    echo "created sshfp record for $SSH_HOST ($ALGORITHM $TYPE $FINGERPRINT)"
done
