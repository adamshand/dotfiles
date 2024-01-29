#!/bin/bash

function print_usage() {
  echo "usage: $(basename $0) <regex>"
  echo "       regex must match a single volume name"
  echo "       returns _data dir of docker volume"
  exit 1
}

if [ ! "$1" ]; then
  print_usage
fi

VOLUME="$(docker volume ls -q | egrep $1)"

if [ $(echo "$VOLUME" | wc -l) -gt 1 ]; then
  echo -e "error: too many volumes: \n${VOLUME}\n"
  print_usage
fi

FOLDER="$(docker volume inspect captain--tink-nz | awk -F\" '/Mountpoint/ {print $4}')"

echo $FOLDER
