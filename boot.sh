#!/usr/bin/env bash
set -euo pipefail

# Professional ASCII Art for Setupr Logo
ascii_art='
███████╗███████╗████████╗██╗   ██╗██████╗ ██████╗ 
██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗██╔══██╗
███████╗█████╗     ██║   ██║   ██║██████╔╝██████╔╝
╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ ██╔══██╗
███████║███████╗   ██║   ╚██████╔╝██║     ██║  ██║
╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     ╚═╝  ╚═╝
'

# Ensure the script is run with sudo (not directly as root)
if [ "$EUID" -eq 0 ] && [ -z "${SUDO_USER:-}" ]; then
    echo "Error: Run with sudo, not as root."
    exit 1
elif [ "$EUID" -ne 0 ]; then
    echo "Error: Run with sudo."
    exit 1
fi

# Check system compatibility
check_system_compatibility() {
    echo "Checking system compatibility..."
    
    # Check if we are on a Debian-based system (Ubuntu, Debian, etc.)
    if ! command -v apt-get &>/dev/null; then
        echo "Error: This script requires a Debian-based system (Ubuntu, Debian, etc.)"
        return 1
    fi
    
    # Check if we can use sudo
    if ! sudo -n true 2>/dev/null; then
        echo "Sudo access required. Please run with sudo privileges."
        return 1
    fi
    
    # Basic internet connectivity check
    if ! ping -c 1 google.com &>/dev/null && ! ping -c 1 github.com &>/dev/null; then
        echo "Error: Internet connectivity is required for installation."
        return 1
    fi
    
    # Check available disk space (at least 5GB free on /)
    local available_space
    available_space=$(df -k / | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 5242880 ]; then # 5GB in KB
        echo "Error: Insufficient disk space. At least 5GB of free space is required on /"
        echo "Available space: $(( available_space / 1024 / 1024 ))GB"
        return 1
    fi
    
    return 0
}

# Run system compatibility check
if ! check_system_compatibility; then
    echo "System compatibility check failed. Please fix the issues and try again."
    exit 1
fi

# Install essential prerequisites
install_prerequisites() {
    echo "Installing essential prerequisites..."
    # Update package lists
    sudo apt-get update
    
    # Install core dependencies required for proper installation
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        curl \
        gnupg \
        wget \
        git \
        
    # Check if build-essential is installed
    if ! dpkg -l | grep -q "^ii.*build-essential"; then
        echo "Installing build-essential package..."
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential
    fi
}

# Check and install all necessary dependencies
install_dependencies() {
    # Make sure prerequisites are installed first
    install_prerequisites
    
    # Then install gum if not already installed
    if ! command -v gum &>/dev/null; then
        echo "Installing dependency: gum..."
        
        # Use modern method for adding repository keys
        if sudo mkdir -p /etc/apt/keyrings && \
           curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg; then
            
            echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | \
                sudo tee /etc/apt/sources.list.d/charm.list
                
            sudo apt-get update -o Dir::Etc::sourcelist="/etc/apt/sources.list.d/charm.list" \
                -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gum
        else
            echo "Error: Failed to add Charm repository key."
            exit 1
        fi
    fi
    
    # Make sure git is installed for cloning the repository
    if ! command -v git &>/dev/null; then
        echo "Git not found. Installing git..."
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git
    fi
}

# Main installation variables
INSTALL_DIR="/usr/local/share/Setupr"
USER_HOME=$(eval echo ~${SUDO_USER})

# Fix common APT issues that might prevent successful installation
fix_apt_issues() {
    echo "Checking and fixing common APT issues..."
    
    # Clear any dpkg locks or interrupted installations
    if [ -f /var/lib/dpkg/lock ] || [ -f /var/lib/apt/lists/lock ] || [ -f /var/cache/apt/archives/lock ]; then
        echo "Clearing package manager locks..."
        sudo rm -f /var/lib/dpkg/lock
        sudo rm -f /var/lib/apt/lists/lock
        sudo rm -f /var/cache/apt/archives/lock
        sudo dpkg --configure -a
    fi
    
    # Fix any broken packages
    sudo apt-get update --fix-missing
    sudo apt-get install -f -y
    
    echo "APT issues fixed."
}

# Execute setup functions
fix_apt_issues
install_dependencies

# Prepare the user environment
mkdir -p "${USER_HOME}/Downloads"
chown -R "${SUDO_USER}:${SUDO_USER}" "${USER_HOME}/Downloads"
# Preserve and set essential environment variables
[ -n "${TERM:-}" ] && export TERM
# Export essential environment variables for proper operation
USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"

# Set proper environment variables to run as the real user
export HOME="$USER_HOME"
export USER="$SUDO_USER"
export LOGNAME="$SUDO_USER"
export XDG_RUNTIME_DIR="/run/user/$(id -u ${SUDO_USER})"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"
export SUDO_HOME="$USER_HOME"  # Additional variable for scripts to use

# Create and set permissions for Downloads directory
mkdir -p "${HOME}/Downloads"
chown -R "${SUDO_USER}:${SUDO_USER}" "${HOME}/Downloads"

# Display logo and notification
echo -e "$ascii_art"
echo "=> Setupr is for fresh Ubuntu 24.04+ installations only!"
echo "Begin installation (ctrl+c to abort)..."

# Remove existing directory if it exists
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
fi

# Clone fresh repository
mkdir -p "$INSTALL_DIR"
echo "Cloning Setupr..."
if ! git clone -b v2.2 https://github.com/ByteTrix/Setupr.git "$INSTALL_DIR"; then
    echo "Error: Failed to clone repository."
    exit 1
fi

# Set executable permissions and ownership for all scripts
chmod +x "$INSTALL_DIR"/{install,check-version,system-update,essential-tools}.sh
chmod +x "$INSTALL_DIR"/modules/*/*.sh 2>/dev/null || true
chown -R "${SUDO_USER}:${SUDO_USER}" "$INSTALL_DIR"

# Source utility functions
source "${INSTALL_DIR}/lib/utils.sh"

# Install essential tools first
log_info "Installing essential tools first..."
sudo -E TERM="$TERM" bash "$INSTALL_DIR/essential-tools.sh"

# Verify essential tools were installed
verify_essentials() {
    log_info "Verifying essential tools installation..."
    local missing_tools=()
    
    # Check for critical tools
    for tool in curl wget git jq gdebi-core snapd; do
        if ! command -v "$tool" &>/dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    # Report if any tools are missing
    if [ "${#missing_tools[@]}" -ne 0 ]; then
        log_warn "Some essential tools could not be installed: ${missing_tools[*]}"
        log_warn "Attempting to install them again..."
        
        # Try to install the missing tools directly
        if [ "${#missing_tools[@]}" -gt 0 ]; then
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing_tools[@]}"
        fi
    else
        log_success "All essential tools are installed!"
    fi
}

# Run the verification
verify_essentials

# Run system update next
log_info "Running system update..."
sudo -E TERM="$TERM" bash "$INSTALL_DIR/system-update.sh"

log_info "Starting Setupr installation..."
# Preserve TERM for proper terminal handling
[ -n "${TERM:-}" ] && export TERM

# Final command: run install.sh while preserving TERM
sudo -E TERM="$TERM" bash "$INSTALL_DIR/install.sh"
