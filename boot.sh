#!/usr/bin/env bash
set -euo pipefail

# ASCII art for Setupr logo
ascii_art='

███████╗███████╗████████╗██╗   ██╗██████╗ ██████╗ 
██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗██╔══██╗
███████╗█████╗     ██║   ██║   ██║██████╔╝██████╔╝
╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ ██╔══██╗
███████║███████╗   ██║   ╚██████╔╝██║     ██║  ██║
╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     ╚═╝  ╚═╝

'

# Check for proper sudo usage
if [ "$EUID" -eq 0 ] && [ -z "${SUDO_USER:-}" ]; then
    echo "Error: Please run with sudo, not as root directly"
    exit 1
elif [ "$EUID" -ne 0 ]; then
    echo "Error: Please run with sudo"
    exit 1
fi

# Set up installation directory and user info
INSTALL_DIR="/usr/local/share/Setupr"
USER_HOME=$(eval echo ~${SUDO_USER})
export USER_HOME

# Set correct environment for sudo user
export HOME="$USER_HOME"
export USER="$SUDO_USER"
export LOGNAME="$SUDO_USER"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"

echo -e "$ascii_art"
echo "=> Setupr is for fresh Ubuntu 24.04+ installations only!"
echo -e "\nBegin installation (or abort with ctrl+c)..."

# Clone or update repository
if [ ! -d "$INSTALL_DIR/.git" ]; then
    mkdir -p "$INSTALL_DIR"
    echo "Cloning Setupr..."
    git clone -b v2.2 https://github.com/ByteTrix/Setupr.git "$INSTALL_DIR" || {
        echo "Error: Failed to clone repository"
        exit 1
    }
else
    echo "Updating Setupr..."
    cd "$INSTALL_DIR"
    # Fetch all updates
    git fetch origin || {
        echo "Error: Failed to fetch latest changes"
        exit 1
    }
    # Reset to v2.2 branch
    git reset --hard origin/v2.2 || {
        echo "Error: Failed to update repository"
        exit 1
    }
    cd - >/dev/null
fi

# Make scripts executable and set permissions
chmod +x "$INSTALL_DIR"/{install,check-version,system-update}.sh
chmod +x "$INSTALL_DIR"/modules/*/*.sh 2>/dev/null || true
chown -R "${SUDO_USER}:${SUDO_USER}" "$INSTALL_DIR"

# Ensure proper permissions for user configs
mkdir -p "${USER_HOME}/Downloads"
chown -R "${SUDO_USER}:${SUDO_USER}" "${USER_HOME}/Downloads"

# Source utility functions with correct environment
sudo -E -u "$SUDO_USER" bash -c "source \"${INSTALL_DIR}/lib/utils.sh\""

# Run system update as root but with correct environment
sudo -E bash "$INSTALL_DIR/system-update.sh"

log_info "Starting Setupr installation..."

# Run install.sh with preserved environment variables
sudo -E -H -u "$SUDO_USER" bash "$INSTALL_DIR/install.sh"
