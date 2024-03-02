#!/bin/bash

source "$(dirname $0)/utilities.sh"

MINIMUM_AGE_DAYS=7

# Function to check image age
check_image_age() {
    local image_creation_date
    image_creation_date=$(docker inspect --format '{{ .Created }}' "$IMAGE_NAME:latest")

    # Convert image creation date to Unix timestamp
    local image_creation_timestamp
    image_creation_timestamp=$(date -d "$image_creation_date" +%s)

    # Get the current Unix timestamp
    local current_timestamp
    current_timestamp=$(date +%s)

    # Calculate age in seconds and convert to days
    local age_seconds=$((current_timestamp - image_creation_timestamp))
    local age_days=$((age_seconds / 86400))

    if [ "$age_days" -ge "$MINIMUM_AGE_DAYS" ]; then
        return 0 # Image is old enough
    else
        return 1 # Image is not old enough
    fi
}

# if docker info -f '{{.Swarm.LocalNodeState}}' | grep --silent inactive; do
if [ "$(docker info -f '{{.Swarm.ControlAvailable}}')" != "true" ]; then
  print_error 'This node is not a Docker Swarm manager'
fi

docker service ls --format "{{.Name}} {{.Image}}" | while read service imageversion; do
    image="${imageversion%:*}"
    echo "Service: $service"
    echo "Image:   $image"

    # Any additional commands using $service_id or $service_name
done

exit
# Check if an update is needed and trigger Docker Swarm service update
if check_image_age ; then
    echo "Updating service $SERVICE_NAME to use latest image $IMAGE_NAME:latest"
    # docker service update --image "$IMAGE_NAME:latest" "$SERVICE_NAME"
else
    echo "Latest image for $IMAGE_NAME is not $MINIMUM_AGE_DAYS days old. Skipping update."
fi
