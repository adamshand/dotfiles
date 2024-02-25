#!/bin/bash
# Get random quote, format and update /etc/issue.net for SSH banner
# Written 19 Jan 2024

QUOTE_URL="https://adam.nz/api/quote?id=random"
# QUOTE_URL="http://localhost:5173/api/quote?id=random"
# QUOTE_URL='https://pb.haume.nz/api/collections/adam/records/?perPage=1&sort=@random&filter=(format="quote")&fields=content,author'
BANNER_FILE="/etc/issue.net"
CURL_OPTIONS="--silent --retry 3 --retry-delay 60"

# sets final exit code as failure if any step in pipeline fails
set -o pipefail
if ! QUOTE=$(curl ${CURL_OPTIONS} ${QUOTE_URL} | fmt -w 60); then
  echo "error: downloading and formatting quote" 1>&2
  exit 1
fi

if ! touch ${BANNER_FILE} > /dev/null 2>&1; then
  DEBUG="yes"
  echo "DEBUG: ${BANNER_FILE} is not writable" 1>&2
fi

if [ "$1" == "debug" ] || [ "${DEBUG}" ]; then
  echo -e "DEBUG: on\n" 1>&2
  echo "$QUOTE"
else
  echo -e "$QUOTE\n" > $BANNER_FILE
fi

# boxes -p h2v1 -d stone -a r
# decoding entites in api now
# python3 -c "import html, sys; print(html.unescape(sys.stdin.read()))" | \
