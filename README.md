# Deployment Script

# Deployment Script

This repository contains a Bash script designed to automate the deployment of an application. The script clones the
repository, builds a Docker image, starts a Docker container, and cleans up old releases and Docker images.

## Folder Structure

The deployment script assumes a specific folder structure on the server where it is executed. Below is a description of
the key directories involved:

```plaintext
{ROOT_DIR}
└── {APP_NAME}/
    └── {APP_TYPE}/
        ├── releases/
        │   ├── 20230827_123456/       # Example release directory (timestamp)
        │   ├── 20230828_101010/       # Example release directory (timestamp)
        │   └── ...                    # Other release directories
        ├── current/                   # Symlink to the current release
        └── {ENV_FOLDER}/              # Environment files directory
            ├── .env                   # Example environment file
            └── ...                    # Other environment files
```

- `{ROOT_DIR}/{APP_NAME}/{APP_TYPE}/releases/`: Contains timestamped directories for each release.
- `{ROOT_DIR}/{APP_NAME}/{APP_TYPE}/current/`: Symlink pointing to the current active release.
- `{ROOT_DIR}/{APP_NAME}/{APP_TYPE}/{ENV_FOLDER}/`: Contains environment files that are copied into each release.

## How the Script Works

### 1. Argument Parsing

The script accepts several optional arguments to customize the deployment. These arguments can override the default
values set within the script.

- --branch or branch: Specifies the Git branch to deploy.
- --commit or commit: Specifies the commit hash to deploy.
- --keep or keep: Number of releases to keep on the server.
- --port or port: The port on which to run the Docker container.
- --type or type: The type of application (e.g., app, service).
- --password or password: Git repository access token.
- --user or user: Git repository user.
- --host or host: Git repository host (e.g., github.com).
- --repository or repository: Repository in the format user/repo.
- --submodules or submodules: Flag to include submodules.
- --name or name: Name of the application.
- --env_folder or env_folder: Folder for environment files.
- --dir or dir: Root directory for deployment.

### 2. Cloning the Repository

The script clones the specified branch of the repository into a new release directory based on the current timestamp.

### 3. Copying Environment Files

If environment files are present in the designated environment folder, they are copied into the new release directory.

### 4. Linking the Current Release

The script creates or updates a symbolic link (current/) to point to the newly deployed release.

### 5. Building the Docker Image

A new Docker image is built from the contents of the newly cloned release.

### 6. Stopping Old Containers

The script identifies and stops any running containers associated with previous releases.

### 7. Starting the New Container

The Docker container for the new release is started, optionally binding it to a specified port.

### 8. Cleaning Up Old Releases and Docker Images

Old release directories and Docker images are purged based on the number of releases to keep.

## Usage

To use this script, make sure it is executable:

```bash
chmod +x deploy.sh
```

You can run the script with or without arguments:

```bash
./deploy.sh --branch=main --commit=HEAD --keep=3 --port=8080 --user=youruser --password=yourpassword --host=github.com --repository=user/repo --submodules=true --name=myapp --env_folder=env_files --dir=/var/www
```

## Customization

    Placeholders: Before using the script, replace the placeholders with your actual values, or pass them as arguments.
    Environment Files: Ensure that the environment files are placed in the correct directory ({ENV_FOLDER}) for them to be copied to the new release.

## Notes

    The script assumes the server is configured with Docker and has sufficient permissions to create directories and manage Docker containers.
    Review the script and adjust any paths or settings specific to your server environment before deploying it in a production environment.

## Contributing

If you have suggestions for improvements or find any issues, feel free to open a pull request or issue.