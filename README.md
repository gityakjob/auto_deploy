## Overview

This project automates the process of monitoring a Git repository, building a Docker image when changes are detected, and pushing the image to AWS ECR. The script (`git_watsh.sh`) performs the following steps:

1. **Monitors a Git repository** for changes using SSH authentication.
2. **Clones or pulls** the latest code from the repository.
3. **Builds a Docker image** with an incremented version tag.
4. **Tags and pushes** the image to AWS Elastic Container Registry (ECR).
5. **Removes old images** from AWS ECR and locally.
6. **Logs all actions** and maintains a version file for tracking.

**Requirements:**  
- SSH access to the Git repository  
- Docker or Podman installed  
- AWS CLI configured with credentials  
- Proper permissions for ECR operations

**Note:**  
Update the configuration variables in the script to match your environment (repository URL, AWS region, user ID, image name, etc.).
