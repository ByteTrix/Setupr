#!/usr/bin/env bash
set -euo pipefail
source ~/.local/share/atelier/lib/utils.sh

log_info "[cli] Installing eza (exa)..."
sudo apt install -y eza
log_info "[cli] eza installed."
