#!/bin/bash

BRANCH="main"
KEEP_RELEASES=3
APP_TYPE="app"
COMMIT="HEAD"
SUBMODULES="false"
ROOT_DIR="/var/www"

for ARG in "$@"; do
    IFS='=' read -r key value <<<"$ARG"

    case "$key" in
    --branch | branch)
        BRANCH="$value"
        ;;
    --commit | commit)
        COMMIT="$value"
        ;;
    --keep | keep)
        KEEP_RELEASES="$value"
        ;;
    --type | type)
        APP_TYPE="$value"
        ;;
    --password | password)
        TOKEN="$value"
        ;;
    --user | user)
        USER="$value"
        ;;
    --host | host)
        HOST="$value"
        ;;
    --repository | repository)
        REPOSITORY="$value"
        ;;
    --submodules | submodules)
        SUBMODULES="true"
        ;;
    --name | name)
        APP_NAME="$value"
        ;;
    --dir | dir)
        ROOT_DIR="$value"
        ;;
    *)
        echo "Unrecognized argument: $key"
        ;;
    esac
done

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

SKIP_AMOUNT=$((KEEP_RELEASES + 1))
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
APP_DIR="$ROOT_DIR/$APP_NAME/$APP_TYPE"
RELEASE_DIR="$APP_DIR/releases"
NEW_RELEASE_DIR="$RELEASE_DIR/$TIMESTAMP"
ENV_FILES_DIR="${APP_DIR}/env_files"

if [[ -z ${BRANCH} || -z ${KEEP_RELEASES} || -z ${APP_TYPE} || -z ${COMMIT} || -z ${ROOT_DIR} || -z ${HOST} || -z ${REPOSITORY} || -z ${APP_NAME} || -z ${REPO_URL} || -z ${SKIP_AMOUNT} || -z ${TIMESTAMP} || -z ${APP_DIR} || -z ${RELEASE_DIR} || -z ${NEW_RELEASE_DIR} || -z ${ENV_FILES_DIR} ]]; then
    echo "Error: Not all necessary variables are set." >&2
    exit 1
fi
