#!/bin/bash
#Source: https://github.com/midnightmonster/icloud-calendar-urls

printf "
iCloud Calendar URLs
====================
"

PRINCIPAL_URL=`/usr/bin/sqlite3 ~/Library/Calendars/Calendar.sqlitedb "select cached_external_info from Store where type=2 limit 1" | grep -oe "p\\d\+-caldav.icloud.com"`
/usr/bin/sqlite3 -list ~/Library/Calendars/Calendar.sqlitedb << SQL
SELECT char(10) || '* ' || title || ' (' || shared_owner_name || ')' ||
  char(10) || '  ' ||
  'https://$PRINCIPAL_URL' ||
  Calendar.external_id
FROM Calendar JOIN Store ON Calendar.store_id = Store.ROWID
WHERE Store.type = 2 ORDER BY Calendar.display_order
SQL
