#!/bin/bash

is_recently_modified() {
  local file="${1:-$0}"
  local days="${2:-7}"

  local now=$(date +%s)
  local mtime=$(stat -c %Y "$file")
  local age=$(( ($now - $mtime) / 86400 ))

  test $DEBUG && echo "file: $file days: $days mtime: $mtime current_time: $current_time age: $age"

  # if file has been modified within $days, return $age
  if [ $age -le $days ]; then
    echo "`basename $file` was modified $age days ago (debug for $days days)"
  fi
}
