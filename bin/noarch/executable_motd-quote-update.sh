#!/bin/bash
# Get random quote, format and update /etc/issue.net for SSH banner
# Written 19 Jan 2024

QUOTE_URL="http://172.16.1.42:5173/api/random/quote"
BANNER_FILE="/etc/issue.net"

set -o pipefail

if ! QUOTE=$(curl --silent --fail "$QUOTE_URL" | \
    python3 -c "import html, sys; print(html.unescape(sys.stdin.read()))" | \
    fmt -w 80 | \
    boxes -p h2v1 -d stone -a r); then
  echo "error: downloading and formatting quote" 1>&2
  exit 1
fi

if [ ! -w "$BANNER_FILE" ]; then
  echo "error: can't write to $BANNER_FILE" 1>&2
  exit 1
fi

echo -e "\n$QUOTE\n" > $BANNER_FILE
