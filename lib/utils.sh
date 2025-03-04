#!/usr/bin/env bash
set -euo pipefail

log_info() {
  echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_warn() {
  echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_error() {
  echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

backup_file() {
  local file="$1"
  if [ -e "$file" ] || [ -L "$file" ]; then
    mv "$file" "${file}.backup.$(date +%s)"
    log_info "Backed up $file"
  fi
}

symlink_file() {
  local source_file="$1"
  local target_file="$2"
  backup_file "$target_file"
  ln -sf "$source_file" "$target_file"
  log_info "Linked $source_file -> $target_file"
}

# Config management functions
load_config() {
  local config_file="$1"
  if [ -f "$config_file" ]; then
    jq -r '.' "$config_file"
  fi
}

save_config() {
  local config_file="$1"
  local config_data="$2"
  echo "$config_data" | jq '.' > "$config_file"
  log_info "Saved config to $config_file"
}

# Function to display installation summary
display_summary() {
  local config_file="$1"
  
  echo "Installation Summary"
  echo "==================="
  if [ -f "$config_file" ]; then
    local mode timestamp packages
    
    mode=$(jq -r '.mode' "$config_file")
    timestamp=$(jq -r '.timestamp' "$config_file")
    
    echo "Mode: $mode"
    echo "Time: $timestamp"
    echo -e "\nSelected Packages:"
    
    jq -r '.packages[]' "$config_file" | while read -r package; do
      echo "  • $package"
    done
  else
    echo "No configuration found."
  fi
  echo
}