RELEASES_TO_PURGE=$(find "${RELEASE_DIR}" -mindepth 1 -maxdepth 1 -type d -print0 | xargs -0 ls -dt | tail -n +"$SKIP_AMOUNT")

if [ "$RELEASES_TO_PURGE" != "" ]; then
    echo "Purging old releases"

    for RELEASE_TO_PURGE in $RELEASES_TO_PURGE; do
        echo "Purging old release: $RELEASE_TO_PURGE"
        rm -rf "$RELEASE_TO_PURGE"
    done
else
    echo "No releases found for purging at this time"
fi

DOCKER_IMAGES_TO_PURGE=$(docker image ls "${APP_NAME}" --format '{{.ID}} {{.CreatedAt}}' | awk -v OFS='\t' '{print $1, $2 "T" $3 "Z"}' | sort -r -k2,2 | tail -n +$SKIP_AMOUNT | cut -f1)

if [ "$DOCKER_IMAGES_TO_PURGE" != "" ]; then
    echo "Purging old Docker images"

    for DOCKER_IMAGE_TO_PURGE in $DOCKER_IMAGES_TO_PURGE; do
        CONTAINERS_TO_PURGE=$(docker ps -a --filter "ancestor=${DOCKER_IMAGE_TO_PURGE}" --format '{{.ID}}')

        if [ "$CONTAINERS_TO_PURGE" != "" ]; then
            for CONTAINER_TO_PURGE in $CONTAINERS_TO_PURGE; do
                echo "Stopping and removing container: $CONTAINER_TO_PURGE"
                docker stop "$CONTAINER_TO_PURGE"
                docker rm "$CONTAINER_TO_PURGE"
            done
        fi

        echo "Purging old Docker image: $DOCKER_IMAGE_TO_PURGE"
        docker image rm "$DOCKER_IMAGE_TO_PURGE"
    done
else
    echo "No Docker images found for purging at this time"
fi

echo "Script executed successfully."
