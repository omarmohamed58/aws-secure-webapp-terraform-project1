#!/usr/bin/env bash
set -euo pipefail
# DEBUG: uncomment next line to trace execution
# set -x

##### Configuration #####
APP_USER=${APP_USER:-websvc}
APP_GROUP=${APP_GROUP:-websvc}
APP_BASE_DIR=${APP_BASE_DIR:-/opt/secure-webapp}
APP_TMP_SOURCE=${APP_TMP_SOURCE:-/tmp/secure-webapp}
APP_ENTRYPOINT=${APP_ENTRYPOINT:-app.py}
VENV_DIR="${APP_BASE_DIR}/venv"
LOG_DIR=${LOG_DIR:-/var/log/secure-webapp}
STDOUT_LOG="${LOG_DIR}/stdout.log"
STDERR_LOG="${LOG_DIR}/stderr.log"
SERVICE_NAME=${SERVICE_NAME:-secure-webapp.service}
PYTHON_BIN=${PYTHON_BIN:-/usr/bin/python3}
PIP_BIN=${PIP_BIN:-pip3}
IMDS_TOKEN_TTL=${IMDS_TOKEN_TTL:-21600}
IMDS_RETRIES=${IMDS_RETRIES:-6}
IMDS_SLEEP=${IMDS_SLEEP:-1}

# Safety: do not hardcode private keys or credentials here.
# Ensure any real secrets are provided via a secure secret manager.

echo "==> bootstrap starting: configuring system and application"

##### Install prerequisites (supports Amazon Linux/CentOS and Debian/Ubuntu) #####
if command -v yum >/dev/null 2>&1; then
  sudo yum update -y
  sudo yum install -y python3 python3-pip python3-venv jq curl
elif command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y python3 python3-pip python3-venv jq curl
else
  echo "Unsupported package manager. Install python3, pip3, curl manually." >&2
fi

##### Create dedicated user & dirs #####
if ! id -u "${APP_USER}" >/dev/null 2>&1; then
  sudo useradd -m -s /bin/bash "${APP_USER}" || true
fi

sudo mkdir -p "${APP_BASE_DIR}"
sudo mkdir -p "${LOG_DIR}"
sudo chown -R "${APP_USER}:${APP_GROUP}" "${APP_BASE_DIR}" "${LOG_DIR}"
sudo chmod 750 "${APP_BASE_DIR}"
sudo chmod 750 "${LOG_DIR}"

##### Copy application files (expecting packaged app at ${APP_TMP_SOURCE}) #####
if [ -d "${APP_TMP_SOURCE}" ] && [ "$(ls -A "${APP_TMP_SOURCE}")" ]; then
  echo "==> copying application files from ${APP_TMP_SOURCE} to ${APP_BASE_DIR}"
  sudo cp -r "${APP_TMP_SOURCE}/." "${APP_BASE_DIR}/"
  sudo chown -R "${APP_USER}:${APP_GROUP}" "${APP_BASE_DIR}"
else
  echo "==> no application files found at ${APP_TMP_SOURCE}; ensure your build pipeline uploads the package there" >&2
fi

##### Set up virtualenv and install requirements if present #####
echo "==> creating virtualenv at ${VENV_DIR}"
sudo -u "${APP_USER}" "${PYTHON_BIN}" -m venv "${VENV_DIR}"
# ensure pip in venv is available
sudo "${VENV_DIR}/bin/${PYTHON_BIN##*/}" -m pip install --upgrade pip setuptools wheel || true

if [ -f "${APP_BASE_DIR}/requirements.txt" ]; then
  echo "==> installing python dependencies"
  sudo -u "${APP_USER}" "${VENV_DIR}/bin/${PYTHON_BIN##*/}" -m pip install -r "${APP_BASE_DIR}/requirements.txt"
else
  echo "==> requirements.txt not found, skipping pip install"
fi

##### IMDSv2 token retrieval with retry (safer metadata access) #####
IMDS_URL="http://169.254.169.254/latest"
fetch_imds_token() {
  local tries=0
  while [ $tries -lt "${IMDS_RETRIES}" ]; do
    token=$(curl -sf -X PUT "${IMDS_URL}/api/token" \
      -H "X-aws-ec2-metadata-token-ttl-seconds: ${IMDS_TOKEN_TTL}" || true)
    if [ -n "${token}" ]; then
      echo "${token}"
      return 0
    fi
    tries=$((tries+1))
    sleep "${IMDS_SLEEP}"
  done
  return 1
}

IMDS_TOKEN=""
if token_val=$(fetch_imds_token); then
  IMDS_TOKEN="${token_val}"
  echo "==> obtained IMDSv2 token"
else
  echo "==> IMDSv2 token unavailable; falling back to IMDSv1 (less secure)" >&2
fi

fetch_metadata() {
  local path="$1"
  if [ -n "${IMDS_TOKEN}" ]; then
    curl -sf -H "X-aws-ec2-metadata-token: ${IMDS_TOKEN}" "${IMDS_URL}/meta-data/${path}" || echo "N/A"
  else
    curl -sf "${IMDS_URL}/meta-data/${path}" || echo "N/A"
  fi
}

INSTANCE_PRIVATE_IP=$(fetch_metadata "local-ipv4")
AZ=$(fetch_metadata "placement/availability-zone")
INSTANCE_ID=$(fetch_metadata "instance-id")
INSTANCE_TYPE=$(fetch_metadata "instance-type")
HOSTNAME=$(fetch_metadata "hostname")

# Derive region safely (remove last character of AZ)
if [ -n "${AZ}" ] && [ "${AZ}" != "N/A" ]; then
  REGION="${AZ::-1}"
else
  REGION="N/A"
fi

##### Write non-sensitive metadata to env file (protected) #####
ENV_FILE="${APP_BASE_DIR}/.service_env"
cat > /tmp/secure_webapp_env.tmp <<EOF
INSTANCE_PRIVATE_IP=${INSTANCE_PRIVATE_IP}
AZ=${AZ}
REGION=${REGION}
INSTANCE_ID=${INSTANCE_ID}
INSTANCE_TYPE=${INSTANCE_TYPE}
HOSTNAME=${HOSTNAME}
EOF

sudo mv /tmp/secure_webapp_env.tmp "${ENV_FILE}"
sudo chown "${APP_USER}:${APP_GROUP}" "${ENV_FILE}"
sudo chmod 640 "${ENV_FILE}"

# Suggest .gitignore entry (won't modify git here)
# echo "/opt/secure-webapp/.service_env" >> .gitignore

##### Create systemd unit to run the app reliably #####
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"
sudo tee "${SERVICE_PATH}" > /dev/null <<EOF
[Unit]
Description=Secure Webapp Backend (fabricated-demo)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
WorkingDirectory=${APP_BASE_DIR}
EnvironmentFile=${ENV_FILE}
ExecStart=${VENV_DIR}/bin/python ${APP_BASE_DIR}/${APP_ENTRYPOINT}
Restart=on-failure
RestartSec=5s
StandardOutput=append:${STDOUT_LOG}
StandardError=append:${STDERR_LOG}

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now "${SERVICE_NAME}"

##### Post-start health check (local) #####
sleep 3
if curl -sf "http://127.0.0.1:5000/" >/dev/null 2>&1; then
  echo "==> local health check OK (http://127.0.0.1:5000/)"
else
  echo "==> local health check failed — check logs at ${LOG_DIR}" >&2
fi

echo "==> bootstrap finished - service: ${SERVICE_NAME}"
exit 0
