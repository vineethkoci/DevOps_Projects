#!/bin/bash
set -euo pipefail
LOG_FILE="/var/log/userdata.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "[userdata] Starting provisioning for ${project}"

# Install Docker
yum update -y
yum install docker -y

# Enable and start docker
systemctl enable docker
systemctl start docker

# Add ec2-user to docker group (takes effect on next login; not needed for userdata)
usermod -a -G docker ec2-user || true

# Run nginx via Docker with log rotation and health wait
# Also pull the image from the custom GIT repo during runtime
docker run -d --name web -p 80:80 --restart unless-stopped \
  --log-driver local --log-opt max-size=10m --log-opt max-file=3 \
  ghcr.io/vineethkoci/nginx-static:latest

for i in $(seq 1 30); do
  if docker ps --filter 'name=web' --filter 'status=running' --format '{{.Names}}' | grep -q '^web$'; then
    echo "[userdata] Nginx container is running"
    break
  fi
  echo "[userdata] Waiting for nginx container to be running ($i/30)"; sleep 2
done

echo "[userdata] Docker installed and nginx container started"


