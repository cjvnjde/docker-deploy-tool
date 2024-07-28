echo "Cloning repository $REPOSITORY to $NEW_RELEASE_DIR"
[ -d "${RELEASE_DIR}" ] || mkdir "${RELEASE_DIR}"
git clone --depth 1 --branch "${BRANCH}" "${REPO_URL}" "${NEW_RELEASE_DIR}"

cd "${NEW_RELEASE_DIR}" || {
    echo "Folder does not exist: ${NEW_RELEASE_DIR}"
    exit 1
}
git reset --hard "${COMMIT}"

if [[ -d "${ENV_FILES_DIR}" ]]; then
    for file in "${ENV_FILES_DIR}"/{,.[!.],..?}*; do
        if [[ -f "${file}" ]]; then
            filename=$(basename "${file}")
            echo "Copying ${file}"
            cp --dereference "${file}" "${NEW_RELEASE_DIR}/${filename}"
        fi
    done
else
    echo "Directory ${ENV_FILES_DIR} does not exist, skipping copy."
fi

echo 'Linking current release'
ln -nfs "${NEW_RELEASE_DIR}" "${APP_DIR}/current"
