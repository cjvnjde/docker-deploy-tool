#!/bin/bash

# ========================================
# Deployment Script
# ========================================
# This script deploys an application by:
# 1. Cloning the repository
# 2. Building a Docker image
# 3. Starting the Docker container
# 4. Cleaning up old releases and Docker images

# ========================================
# Variables (Replace with your values)
# ========================================

APP_NAME="APP_NAME_PLACEHOLDER"            # Application name
HOST="HOST_PLACEHOLDER"                    # Git repository host (e.g., github.com)
REPOSITORY="REPOSITORY_PLACEHOLDER"        # Repository (e.g., user/repo)

ENV_FOLDER="env_files" # Folder for environment files

BRANCH="main" # Branch to deploy
KEEP_RELEASES=3 # Number of releases to keep
APP_TYPE="app" # Type of application (e.g., app, service)
COMMIT="HEAD"  # Commit to deploy
SUBMODULES="false" # Include submodules (true/false)
ROOT_DIR="/var/www" # Root directory for deployment

CONTAINER_PORT="3100"

# ========================================
# Argument Parsing
# ========================================
for ARG in "$@"; do
  IFS='=' read -r key value <<<"$ARG"
  case "$key" in
    --branch | branch) BRANCH="$value" ;;
    --commit | commit) COMMIT="$value" ;;
    --keep | keep) KEEP_RELEASES="$value" ;;
    --port | port) PORT="$value" ;;
    --type | type) APP_TYPE="$value" ;;
    --password | password) TOKEN="$value" ;;
    --user | user) USER="$value" ;;
    --host | host) HOST="$value" ;;
    --repository | repository) REPOSITORY="$value" ;;
    --submodules | submodules) SUBMODULES="true" ;;
    --name | name) APP_NAME="$value" ;;
    --env_folder | env_folder) ENV_FOLDER="$value" ;;
    --dir | dir) ROOT_DIR="$value" ;;
    *) echo "Unrecognized argument: $key" ;;
  esac
done

# ========================================
# Repository URL Construction
# ========================================
if [[ -n "$REPOSITORY" ]]; then
  IFS="/" read -ra LAST_ARG <<<"$REPOSITORY"
  REPO_NAME=${LAST_ARG[-1]}

  if [[ -z "$APP_NAME" ]]; then
    APP_NAME=$REPO_NAME
  fi
fi

if [[ -n "$USER" ]] && [[ -n "$TOKEN" ]]; then
  REPO_URL="https://$USER:$TOKEN@$HOST/$REPOSITORY.git"
else
  REPO_URL="git@$HOST:$REPOSITORY.git"
fi

if [[ "$SUBMODULES" == "true" ]]; then
  REPO_URL="$REPO_URL --recurse-submodules"
fi

# ========================================
# Paths and Directories
# ========================================
SKIP_AMOUNT=$((KEEP_RELEASES + 1))
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
APP_DIR="$ROOT_DIR/$APP_NAME/$APP_TYPE"
RELEASE_DIR="$APP_DIR/releases"
NEW_RELEASE_DIR="$RELEASE_DIR/$TIMESTAMP"
ENV_FILES_DIR="$APP_DIR/$ENV_FOLDER"
DOCKER_NAME="$APP_NAME-$APP_TYPE"

# ========================================
# Check for Necessary Variables
# ========================================
if [[ -z ${BRANCH} || -z ${KEEP_RELEASES} || -z ${APP_TYPE} || -z ${COMMIT} ||
      -z ${ROOT_DIR} || -z ${HOST} || -z ${REPOSITORY} || -z ${APP_NAME} ||
      -z ${REPO_URL} || -z ${SKIP_AMOUNT} || -z ${TIMESTAMP} || -z ${APP_DIR} ||
      -z ${RELEASE_DIR} || -z ${NEW_RELEASE_DIR} || -z ${ENV_FILES_DIR} ]]; then
  echo "Error: Not all necessary variables are set." >&2
  exit 1
fi

# ========================================
# Create Directories
# ========================================
mkdir -p "$APP_DIR" || { echo "Failed to create $APP_DIR"; exit 1; }
mkdir -p "$RELEASE_DIR" || { echo "Failed to create $RELEASE_DIR"; exit 1; }
mkdir -p "$ENV_FILES_DIR" || { echo "Failed to create $ENV_FILES_DIR"; exit 1; }

# ========================================
# Cloning the Repository
# ========================================
echo "Cloning repository $REPOSITORY to $NEW_RELEASE_DIR"
git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$NEW_RELEASE_DIR"

cd "${NEW_RELEASE_DIR}" || {
  echo "Failed to clone repository: $NEW_RELEASE_DIR"
  exit 1
}

git reset --hard "$COMMIT" || { echo "Failed to reset to commit $COMMIT"; exit 1; }

# ========================================
# Copying Environment Files
# ========================================
if [[ -d "${ENV_FILES_DIR}" ]]; then
  for file in "$ENV_FILES_DIR"/{,.[!.],..?}*; do
    if [[ -f "${file}" ]]; then
      filename=$(basename "$file")
      echo "Copying $file"
      cp --dereference "$file" "${NEW_RELEASE_DIR}/${filename}" || { echo "Failed to copy $file"; exit 1; }
    fi
  done
else
  echo "Directory $ENV_FILES_DIR does not exist, skipping copy."
fi

# ========================================
# Linking Current Release
# ========================================
echo 'Linking current release'
ln -nfs "$NEW_RELEASE_DIR" "$APP_DIR/current" || { echo "Failed to link current release"; exit 1; }

# ========================================
# Building Docker Image
# ========================================
docker build -t "$DOCKER_NAME:$TIMESTAMP" . || { echo "Failed to build Docker image"; exit 1; }

# ========================================
# Stopping Old Containers
# ========================================
OLD_CONTAINER_IDS=$(docker ps -q --filter "name=${DOCKER_NAME}")

if [ -n "$OLD_CONTAINER_IDS" ]; then
  for CONTAINER_ID in $OLD_CONTAINER_IDS; do
    echo "Stopping old container: $CONTAINER_ID"
    docker stop "$CONTAINER_ID" || { echo "Failed to stop container $CONTAINER_ID"; exit 1; }
  done
else
  echo "No running containers found with name: $DOCKER_NAME"
fi

# ========================================
# Starting New Container
# ========================================
docker_run_cmd="docker run -d --restart unless-stopped --name ${DOCKER_NAME}_${TIMESTAMP}"

if [[ -n ${PORT} ]]; then
  echo "Starting container on port $PORT"
  docker_run_cmd+=" -p $PORT:$CONTAINER_PORT"
fi

eval $docker_run_cmd "\"$DOCKER_NAME:$TIMESTAMP\"" || { echo "Failed to start container"; exit 1; }

# ========================================
# Cleaning Old Releases and Docker Images
# ========================================
RELEASES_TO_PURGE=$(find "$RELEASE_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | xargs -0 ls -dt | tail -n +"$SKIP_AMOUNT")

if [ "$RELEASES_TO_PURGE" != "" ]; then
  echo "Purging old releases"

  for RELEASE_TO_PURGE in $RELEASES_TO_PURGE; do
    echo "Purging old release: $RELEASE_TO_PURGE"
    rm -rf "$RELEASE_TO_PURGE" || { echo "Failed to purge release $RELEASE_TO_PURGE"; exit 1; }
  done
else
  echo "No releases found for purging at this time"
fi

DOCKER_IMAGES_TO_PURGE=$(docker image ls "$DOCKER_NAME" --format '{{.ID}} {{.CreatedAt}}' | awk -v OFS='\t' '{print $1, $2 "T" $3 "Z"}' | sort -r -k2,2 | tail -n +$SKIP_AMOUNT | cut -f1)

if [ "$DOCKER_IMAGES_TO_PURGE" != "" ]; then
  echo "Purging old Docker images"

  for DOCKER_IMAGE_TO_PURGE in $DOCKER_IMAGES_TO_PURGE; do
    CONTAINERS_TO_PURGE=$(docker ps -a --filter "ancestor=$DOCKER_IMAGE_TO_PURGE" --format '{{.ID}}')

    if [ "$CONTAINERS_TO_PURGE" != "" ]; then
      for CONTAINER_TO_PURGE in $CONTAINERS_TO_PURGE; do
        echo "Stopping and removing container: $CONTAINER_TO_PURGE"
        docker stop "$CONTAINER_TO_PURGE" || { echo "Failed to stop container $CONTAINER_TO_PURGE"; exit 1; }
        docker rm "$CONTAINER_TO_PURGE" || { echo "Failed to remove container $CONTAINER_TO_PURGE"; exit 1; }
      done
    fi

    echo "Purging old Docker image: $DOCKER_IMAGE_TO_PURGE"
    docker image rm "$DOCKER_IMAGE_TO_PURGE" || { echo "Failed to remove Docker image $DOCKER_IMAGE_TO_PURGE"; exit 1; }
  done
else
  echo "No Docker images found for purging at this time"
fi

echo "Script executed successfully."
