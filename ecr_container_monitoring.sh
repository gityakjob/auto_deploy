#!/bin/bash

# Configuration variables
AWS_REGION="us-east-1" # Example: us-east-1
AWS_ACCOUNT_ID="123456789012" # Your AWS account ID
ECR_REPOSITORY_NAME="image_name/id_xx" # The name of your ECR repository
IMAGE_NAME="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY_NAME}"

# --- SPECIFIC VARIABLES FOR DOCKER-COMPOSE ---
DOCKER_COMPOSE_FILE="/home/ubuntu/folder_to_website/docker-compose.yml" # IMPORTANT! Full path to your docker-compose.yml file
DOCKER_COMPOSE_SERVICE_NAME="service_name" # The name of the service in your docker-compose.yml (e.g.: web, app, api)
# ---------------------------------------------------

# --- DO NOT MODIFY BELOW THIS LINE (unless you know what you're doing) ---

LOG_FILE="/home/ubuntu/folder_to_website/log/ecr_monitor_${DOCKER_COMPOSE_SERVICE_NAME}.log" # Path to the log file
LOCK_FILE="/home/ubuntu/folder_to_website/log/ecr_monitor_${DOCKER_COMPOSE_SERVICE_NAME}.lock" # Lock file to prevent simultaneous executions

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a ${LOG_FILE}
}

# Check if there is already an instance of the script running
if [ -f ${LOCK_FILE} ]; then
    log "Error: There is already an instance of ${0} running. Exiting."
    exit 1
fi

# Create lock file
touch ${LOCK_FILE}

# Ensure the lock file is removed on exit
trap "rm -f ${LOCK_FILE}" EXIT

log "Starting ECR monitoring for ${ECR_REPOSITORY_NAME} (with Docker Compose)..."

# Validate that the docker-compose file exists
if [ ! -f "${DOCKER_COMPOSE_FILE}" ]; then
    log "Error: The docker-compose.yml file was not found at ${DOCKER_COMPOSE_FILE}. Check the path."
    exit 1
fi

# 1. Authenticate to ECR
log "Authenticating to ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
if [ $? -ne 0 ]; then
    log "Error: Failed to authenticate to ECR. Check your AWS CLI credentials and region."
    exit 1
fi
log "Successfully authenticated to ECR."

# 2. Get the current "latest" image ID in ECR
ECR_IMAGE_DIGEST=$(aws ecr describe-images \
    --repository-name ${ECR_REPOSITORY_NAME} \
    --image-ids imageTag=latest \
    --query 'imageDetails[0].imageDigest' \
    --output text \
    --region ${AWS_REGION} 2>/dev/null) # Redirect stderr to /dev/null to avoid errors if the image does not exist

if [ -z "$ECR_IMAGE_DIGEST" ] || [ "$ECR_IMAGE_DIGEST" == "None" ]; then
    log "Warning: The 'latest' image was not found in the ECR repository or the digest is null. Checking if the local image exists."
    LOCAL_IMAGE_DIGEST="N/A" # Set a value to compare if there is no image in ECR
else
    log "Latest image digest in ECR (latest): ${ECR_IMAGE_DIGEST}"
fi

# 3. Get the "latest" local Docker image ID
# Note: docker-compose pull is more suitable here as it checks the service image
log "Checking local image for service ${DOCKER_COMPOSE_SERVICE_NAME}..."
# First, try to pull to ensure the local image is up to date or exists
docker-compose -f "${DOCKER_COMPOSE_FILE}" pull "${DOCKER_COMPOSE_SERVICE_NAME}"
if [ $? -ne 0 ]; then
    log "Warning: Failed to run docker-compose pull for ${DOCKER_COMPOSE_SERVICE_NAME}. The image may not exist yet."
fi

# Get the digest of the image that docker-compose will use
# This is a bit more complex because docker-compose uses the image name in the yml
# Assuming your docker-compose.yml uses the image ${IMAGE_NAME}:latest for your service.
LOCAL_IMAGE_DIGEST=$(docker images --no-trunc --quiet ${IMAGE_NAME}:latest 2>/dev/null)

if [ -z "$LOCAL_IMAGE_DIGEST" ]; then
    log "The image ${IMAGE_NAME}:latest was not found locally after verification. This could be a problem."
    # If there is no local image after a pull, exit.
    exit 1
fi

log "Local image digest (latest): ${LOCAL_IMAGE_DIGEST}"

# 4. Compare the image IDs
if [ "$ECR_IMAGE_DIGEST" == "$LOCAL_IMAGE_DIGEST" ]; then
    log "The 'latest' image in ECR is the same as the local image. No changes required."
else
    log "Changes detected in the 'latest' image from ECR!"
    log "ECR Digest: ${ECR_IMAGE_DIGEST}"
    log "Local Digest: ${LOCAL_IMAGE_DIGEST}"

    # 5. Download the new image (docker-compose pull already did this in step 3, but we repeat for clarity and in case it failed before)
    log "Downloading the new image via docker-compose pull for service ${DOCKER_COMPOSE_SERVICE_NAME}..."
    docker-compose -f "${DOCKER_COMPOSE_FILE}" pull "${DOCKER_COMPOSE_SERVICE_NAME}"
    if [ $? -ne 0 ]; then
        log "Error: Failed to download the new image with docker-compose pull. Aborting."
        exit 1
    fi
    log "New image successfully downloaded with docker-compose pull."

    # 6. Rebuild and restart the Docker Compose service
    log "Restarting the Docker Compose service: ${DOCKER_COMPOSE_SERVICE_NAME}..."
    docker stop "${DOCKER_COMPOSE_SERVICE_NAME}" && docker rm "${DOCKER_COMPOSE_SERVICE_NAME}"
    if [ $? -ne 0 ]; then
        log "Error: Failed to restart the Docker Compose service ${DOCKER_COMPOSE_SERVICE_NAME}."
        exit 1
    fi
    log "Docker Compose service ${DOCKER_COMPOSE_SERVICE_NAME} updated and launched successfully."
fi

log "ECR monitoring completed."
