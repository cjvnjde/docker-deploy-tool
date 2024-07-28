#!/bin/bash

source ./parse-arguments.sh "$@"

./git-clone.sh

docker build -t "${APP_NAME}:${TIMESTAMP}" .

OLD_CONTAINER_IDS=$(docker ps -q --filter "name=${APP_NAME}")

if [ -n "$OLD_CONTAINER_IDS" ]; then
    for CONTAINER_ID in $OLD_CONTAINER_IDS; do
        echo "Stopping old container: $CONTAINER_ID"
        docker stop "$CONTAINER_ID"
    done
else
    echo "No running containers found with name: $APP_NAME"
fi

echo "Starting container"

./start-docker.sh

./cleanup.sh