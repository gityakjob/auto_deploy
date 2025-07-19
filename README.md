## Overview
This project automates the process of monitoring a Git repository, building a Docker image when changes are detected, and pushing the image to AWS ECR. It also provides tools to monitor and update running containers that use images from ECR. The main scripts included are:

- **`git_watsh.sh`**: Handles repository monitoring, image building, and ECR management.
- **`ecr_container_monitoring.sh`**: Monitors running containers, updates images from ECR, and restarts services as needed.

A sample **`Dockerfile`** is provided to allow you to build and test the Docker image locally before using the full automation workflow.

### `git_watsh.sh` Workflow

1. **Monitors a Git repository** for changes using SSH authentication.
2. **Clones or pulls** the latest code from the repository.
3. **Builds a Docker image** with an incremented version tag.
4. **Tags and pushes** the image to AWS Elastic Container Registry (ECR).
5. **Removes old local images** with the same name and untags the previous `latest` image in ECR before pushing the new one.
6. **Logs all actions** and maintains a version file for tracking.

### `ecr_container_monitoring.sh` Workflow

1. **Authenticates with Amazon ECR** to access private container images.
2. **Checks running Docker containers** and compares their image versions with the latest available in ECR.
3. **Downloads and updates images** from ECR if a newer version is detected.
4. **Stops and removes the old container**, relying on the `restart: always` policy in the `docker-compose.yml` file to automatically restart the service with the updated image.
5. **Logs events and actions** for auditing and monitoring purposes.

**Requirements:**  
- SSH access to the Git repository  
- Docker or Podman installed  
- AWS CLI configured with credentials  
- Proper permissions for ECR operations  
- `docker-compose.yml` file for service management (for container monitoring)

**Note:**  
Update the configuration variables in both scripts to match your environment (repository URL, AWS region, user ID, image name, etc.).

## Usage

### For `git_watsh.sh`

- Configure the script with your repository and ECR details.
- Use the provided `Dockerfile` to build and test the image locally before running the full automation.
- Run the script to automate build and deployment when repository changes are detected.

### For `ecr_container_monitoring.sh`

1. Place the script on the AWS instance where your Docker containers are running.
2. Ensure that the `docker-compose.yml` file is in the same directory or adjust the paths as needed.
3. Grant execution permissions to the script:
    ```bash
    chmod +x ecr_container_monitoring.sh
    ```
4. To monitor and update containers automatically every minute, configure a cron job with a 1-minute interval. Edit your crontab with:
    ```bash
    crontab -e
    ```
    And add the following line:
    ```cron
    * * * * * /ruta/al/script/ecr_container_monitoring.sh >> /ruta/al/log/ecr_monitor.log 2>&1
    ```
    Replace `/ruta/al/script/` and `/ruta/al/log/` with the actual paths on your system.
5. The script will handle ECR authentication, update images, and restart the services defined in `docker-compose.yml` if changes are detected.

**Note:** Make sure the instance has the appropriate IAM permissions to access ECR and manage Docker containers.

**VPC Configuration Note:** To minimize costs from inter-availability zone data transfer, the VPC is configured to use a single subnet. This is the subnet where the EC2 instance is located, ensuring that traffic does not cross availability zones.