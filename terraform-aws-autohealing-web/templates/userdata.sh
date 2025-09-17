#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/userdata.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[userdata] Starting provisioning for ${project}"

if command -v dnf >/dev/null 2>&1; then
  dnf update -y
  dnf install -y nginx
else
  yum update -y
  amazon-linux-extras enable nginx1
  yum install -y nginx
fi

systemctl enable nginx
systemctl start nginx

echo "[userdata] Nginx installed and started"


