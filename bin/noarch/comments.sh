#!/bin/bash

# checks unapproved comments for adam.nz

URL='https://pb.haume.nz'
USER='bot@adam.nz'
PASS='DangerPants!'

TOKEN=$(curl -s \
  -X POST $URL/api/collections/users/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity": "bot@adam.nz", "password": "DangerPants!"}' | jq -r '.token')

# echo "TOKEN: $TOKEN"

COMMENTS=$(curl -s "${URL}/api/collections/adam_comments/records?filter=isApproved=false" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" | \
  jq -r '.items | group_by(.location)[] | 
    .[0].location as $loc | 
    "\n## \($loc)\n" + 
    (map("- created: \(.name) <\(.email)>\n  \(.text[0:30])" + if (.text | length > 30) then "..." else "" end) | join("\n"))')

# echo "COMMENTS: __${COMMENTS}__"

if [ -n "$COMMENTS" ]; then
  echo "there are comments"
  echo $COMMENTS
fi

# EXAMPLE POST
# curl -X POST ${URL}/api/collections/posts/records \
#             -H "Authorization: Bearer $TOKEN" \
#             -H "Content-Type: multipart/form-data" \
#             -F "image=@/tmp/garden-photos/IMG_0045.jpeg" \
#             -F "html=$(ipsum 2 2)"