#!/usr/bin/env bash
set -euo pipefail
source ~/.local/share/Setupr/lib/utils.sh

log_info "[containers] Installing Docker Compose..."
apt install -y docker-compose
log_info "[containers] Docker Compose installed."
