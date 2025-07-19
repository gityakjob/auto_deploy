#!/bin/bash

# This function requires SSH access to be configured in Git to perform remote operations securely.
# Make sure you have added your SSH public key to your Git account and that the SSH agent is running.

# --- Configuration ---
DIR_ROOT="folder_to_store_repo"
REPO_DIR="${DIR_ROOT}/repo_folder" # Change this to the real path of your Git repository!

REPO_GIT="github.com/user/repo.git"
REPO_URL="git@${REPO_GIT}" # Example for GitHub

ID="xx" #ID for docker image
REGION="us-east-1" #default
USER="123456789012" #User ID for AWS ECR

DOCKER="docker" #docker or podman container manager
ECR_URL="${USER}.dkr.ecr.${REGION}.amazonaws.com"
IMAGE_NAME="image_name"
DOCKER_IMAGE_NAME="${ECR_URL}/${IMAGE_NAME}/${ID}"
DOCKERFILE_PATH="$REPO_DIR/Dockerfile"
BUILD_COMMAND="${DOCKER} build -t ${DOCKER_IMAGE_NAME}"
RUN_COMMAND="${DOCKER} push ${DOCKER_IMAGE_NAME}"
RUN_TAG_IMAGE="${DOCKER} tag ${DOCKER_IMAGE_NAME}"
AWS_REMOVE="aws ecr batch-delete-image --repository-name ${IMAGE_NAME}/${ID} --image-ids imageTag=latest"
VERSION_FILE="${DIR_ROOT}/version_${ID}.txt"
LOG_FILE="/tmp/git_docker_monitor_${ID}.log"
TAG="latest"

# --- Functions ---

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

get_current_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE"
    else
        echo "1.0.0"
    fi
}

increment_version() {
    local current_version=$1
    IFS='.' read -r major minor patch <<< "$current_version"
    new_patch=$((patch + 1))
    echo "${major}.${minor}.${new_patch}"
}

check_repo() {
    log_message "Checking the Git repository at $REPO_DIR..."

    if [ ! -d "$REPO_DIR" ]; then
        log_message "Repository directory $REPO_DIR does not exist. Cloning from $REPO_URL..."
        git clone "$REPO_URL" "$REPO_DIR"
        if [ $? -ne 0 ]; then
            git config --global --add safe.directory "${REPO_DIR}"
            log_message "ERROR: Could not clone the repository from $REPO_URL. Check your SSH keys or the URL."
            return 1
        fi
    fi

    cd "$REPO_DIR" || { log_message "ERROR: Could not change to directory $REPO_DIR."; return 1; }

    local current_commit=$(git rev-parse HEAD)

    # Pull to get the latest changes
    git pull origin $(git rev-parse --abbrev-ref HEAD) # Pulls from the current branch
    if [ $? -ne 0 ]; then
        log_message "WARNING: 'git pull' failed. There may be no changes, network issues, or SSH authentication problems."
        return 1
    fi

    local new_commit=$(git rev-parse HEAD)

    if [ "$current_commit" != "$new_commit" ]; then
        log_message "Changes detected in the repository!"
        return 0
    else
        log_message "No changes detected in the repository."
        return 1
    fi
}

build_and_run_docker() {
    local current_version=$(get_current_version)
    local new_version=$(increment_version "$current_version")

    log_message "Removing old images of ${DOCKER_IMAGE_NAME}..."
    "${DOCKER}" images --filter "reference=${DOCKER_IMAGE_NAME}" --format "{{.ID}}" | xargs -r "${DOCKER}" rmi --force

    log_message "Building Docker image with version: ${DOCKER_IMAGE_NAME}:${new_version}"
    cd "$REPO_DIR" || { log_message "ERROR: Could not change to directory $REPO_DIR to build Docker."; return 1; }
    
    if ! $BUILD_COMMAND:"$new_version" .; then
        log_message "ERROR: Docker image build failed."
        return 1
    fi

    # Login to AWS ECR
    # Make sure AWS CLI is configured with AWS credentials
    aws ecr get-login-password --region "${REGION}" | "${DOCKER}" login --username AWS --password-stdin "${ECR_URL}"

    if ! $AWS_REMOVE ; then
        log_message "ERROR: Image not removed in AWS ECR"
    fi

    if ! $RUN_TAG_IMAGE:"$new_version" "$DOCKER_IMAGE_NAME":"$TAG" ; then
        log_message "ERROR: Failed to create the latest image tag"
    fi

    if ! $RUN_COMMAND:"$TAG" ; then
        log_message "ERROR: Could not push the image to AWS ECR"
    fi

    echo "$new_version" > "$VERSION_FILE"
    log_message "Build and deployment completed for version: ${new_version}"
    return 0
}

clear_log_files() {
    MAX_LINES=100
    if [ "$CURRENT_LINES" -gt "$MAX_LINES" ]; then
        tail -n "$MAX_LINES" "$LOG_FILE" > "${LOG_FILE}.tmp"
        if [ $? -eq 0 ] && [ -s "${LOG_FILE}.tmp" ]; then
            mv "${LOG_FILE}.tmp" "$LOG_FILE"
        else
            rm -f "${LOG_FILE}.tmp"
        fi
    fi
}

# --- Main loop ---
log_message "Starting monitoring of the Git repository..."

#while true; do
if check_repo; then
    log_message "Changes detected, proceeding to build and run Docker..."
    if ! build_and_run_docker; then
        log_message "ERROR: Docker container build or deployment failed."
    fi
fi

# Get the current number of lines in the log
CURRENT_LINES=$(wc -l < "$LOG_FILE")
clear_log_files


