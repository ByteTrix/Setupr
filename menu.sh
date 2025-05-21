#!/bin/bash
# Setupr Installation Menu - Clean & Enhanced with gum animations

# Strict mode
set -o errexit -o nounset -o pipefail

# Determine script directory and load utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"

# Update terminal dimensions
update_term_size() {
    # Try tput first
    if TERM_WIDTH=$(tput cols 2>/dev/null); then
        TERM_HEIGHT=$(tput lines 2>/dev/null)
    # Try stty next
    elif size=$(stty size 2>/dev/null); then
        TERM_HEIGHT=${size% *}
        TERM_WIDTH=${size#* }
    # Default fallback values
    else
        TERM_WIDTH=80
        TERM_HEIGHT=24
    fi
}

# Initialize dimensions
update_term_size

# Update on window size changes
trap update_term_size WINCH

# Ensure gum is installed
if ! command -v gum &>/dev/null; then
    log_error "'gum' command not found. Please install gum first."
    exit 1
fi

# Define package categories
declare -A LANGUAGES=(
    ["Python Development Suite"]="python3:apt python3-pip:apt"
    ["Node.js Development Stack"]="nodejs:apt npm:apt"
    ["Java Development Kit (JDK)"]="default-jdk:apt default-jre:apt"
    ["Ruby Development Tools"]="ruby:apt ruby-bundler:apt"
    ["Go Programming Language"]="golang:apt"
    ["Rust Development Tools"]="rustc:apt cargo:apt"
    ["PHP Development Stack"]="php:apt php-cli:apt php-fpm:apt"
    ["Perl Programming Suite"]="perl:apt cpanminus:apt"
    ["Swift Development Tools"]="swift:apt"
    ["Kotlin Development Kit"]="kotlin:apt"
)
declare -A IDES=(
    ["Visual Studio Code"]="code:vscode"
    ["Sublime Text"]="sublime-text:apt"
    ["NeoVim"]="nvim:snap"
    ["PyCharm Community"]="pycharm-community:snap"
    ["IntelliJ IDEA Community"]="intellij-idea-community:snap"
    ["Android Studio"]="android-studio:snap"
    ["Vim"]="vim:apt"
)
declare -A BROWSERS=(
    ["Firefox"]="firefox:snap"
    ["Google Chrome"]="google-chrome-stable:apt"
    ["Brave"]="brave-browser:apt"
    ["Opera"]="opera-stable:apt"
)
declare -A DEVTOOLS=(
    ["Docker & Docker Compose"]="docker:apt docker-compose:apt"
    ["Postman"]="postman:snap"
    ["GitKraken"]="gitkraken:snap"
    ["DBeaver"]="dbeaver-ce:snap"
)
declare -A COMMUNICATION=(
    ["Slack"]="slack:snap"
    ["Discord"]="discord:snap"
    ["Microsoft Teams"]="teams:snap"
    ["Telegram"]="telegram-desktop:snap"
    ["Signal"]="signal-desktop:snap"
)
declare -A MEDIA=(
    ["VLC Media Player"]="vlc:snap"
    ["OBS Studio"]="obs-studio:snap"
    ["GIMP"]="gimp:snap"
    ["Inkscape"]="inkscape:snap"
    ["Kdenlive"]="kdenlive:snap"
    ["Spotify"]="spotify:snap"
)
declare -A PRODUCTIVITY=(
    ["LibreOffice"]="libreoffice:snap"
    ["Obsidian"]="obsidian:snap"
    ["Notion"]="notion-snap:snap"
    ["Bitwarden"]="bitwarden:snap"
)
declare -A CLI=(
    ["Tmux"]="tmux:apt"
    ["Ripgrep"]="ripgrep:apt"
    ["FZF"]="fzf:apt"
    ["Bat"]="bat:apt"
    ["Exa"]="exa:apt"
    ["JQ"]="jq:apt"
    ["Htop"]="htop:apt"
    ["NCDU"]="ncdu:apt"
)

# Map category names to their arrays
declare -A CATEGORIES=(
    ["Development Languages"]="LANGUAGES"
    ["Code Editors & IDEs"]="IDES"
    ["Web Browsers"]="BROWSERS"
    ["Developer Tools"]="DEVTOOLS"
    ["Communication Apps"]="COMMUNICATION"
    ["Media & Creative"]="MEDIA"
    ["Productivity Tools"]="PRODUCTIVITY"
    ["Command Line Tools"]="CLI"
)

# Global selections
declare -A selected_count=()
declare -a selected_packages=()

# Display a header using gum style
show_header() {
    clear
    gum style --align center --width "$TERM_WIDTH" --foreground 99 "$1"
}

# Display instructions
show_instructions() {
    gum style --align center --foreground 212 "$1"
}

# Display a status bar at the bottom
show_status_bar() {
    local total="${#selected_packages[@]}"
    local msg
    if [ "$total" -gt 0 ]; then
        msg="$(gum style --foreground 82 "${total} package(s) selected. Press ENTER to proceed.")"
    else
        msg="$(gum style --foreground 240 "No packages selected. Use SPACE to add selections.")"
    fi
    echo "$msg"
}

# Package selection menu for a given category
select_packages() {
    local category="$1"
    local array_name="${CATEGORIES[$category]}"
    local -n pkg_array="$array_name"
    local options=()
    local pkg_names=()
    local pkg_values=()

    # Build options with markers and store package info
    for pkg in "${!pkg_array[@]}"; do
        pkg_names+=("$pkg")
        pkg_values+=("${pkg_array[$pkg]}")
        if [[ " ${selected_packages[*]} " == *" ${pkg_array[$pkg]} "* ]]; then
            options+=("✓ $pkg")
        else
            options+=("• $pkg")
        fi
    done

    show_header "$category"
    show_instructions "SPACE or "X" to select | ENTER to go Back"
    show_status_bar

    # Calculate available height for the menu
    local menu_height=$((${#options[@]} + 2))
    [ "$menu_height" -gt $((TERM_HEIGHT - 6)) ] && menu_height=$((TERM_HEIGHT - 6))

    # Allow multiple selections via gum choose
    local chosen
    chosen=$(printf '%s\n' "${options[@]}" | sed 's/^[^[:alnum:]]* //' | \
        gum choose --no-limit --cursor.foreground="212" --selected.foreground="82" \
        --height="$menu_height") || return 1

    # Process selections using the stored package info
    while IFS= read -r sel; do
        for i in "${!pkg_names[@]}"; do
            if [[ "${pkg_names[$i]}" == "$sel" ]]; then
                local pkg_value="${pkg_values[$i]}"
                if [[ ! " ${selected_packages[*]} " =~ " ${pkg_value} " ]]; then
                    selected_packages+=("$pkg_value")
                    selected_count["$category"]=$(( selected_count["$category"] + 1 ))
                    gum style --foreground 82 "✓ Added $sel"
                fi
                break
            fi
        done
    done <<< "$chosen"
    sleep 0.5
}

# Display summary and prompt for installation
show_summary_and_install() {
    if [ "${#selected_packages[@]}" -eq 0 ]; then
        show_header "Installation Summary"
        gum style --border double --foreground 196 --align center "No packages selected. Please select at least one package."
        sleep 1
        return
    fi

    local summary=""
    show_header "Installation Summary"
    for cat in "${!CATEGORIES[@]}"; do
        local count="${selected_count[$cat]:-0}"
        if [ "$count" -gt 0 ]; then
            summary+=$(gum style --foreground 99 --bold "◆ $cat ($count)")$'\n'
            local array_name="${CATEGORIES[$cat]}"
            local -n pkg_array="$array_name"
            for pkg in "${!pkg_array[@]}"; do
                if [[ " ${selected_packages[*]} " == *" ${pkg_array[$pkg]} "* ]]; then
                    summary+="  $(gum style --foreground 212 "→") $(gum style --foreground 255 "$pkg")"$'\n'
                fi
            done
            summary+=$'\n'
        fi
    done

    echo "$summary" | gum style --border double --align left --width $((TERM_WIDTH - 10)) --padding "1 2"
    
    # Save selected packages and output to FD 3
    local package_list=()
    for pkg in "${selected_packages[@]}"; do
        read -ra pkg_parts <<< "$pkg"
        for part in "${pkg_parts[@]}"; do
            package_list+=("$part")
        done
    done

    if [ "$SAVE_CONFIG_MODE" -eq 1 ]; then
        # In save config mode, just output packages and exit
        printf "%s\n" "${package_list[@]}" >&3
        exit 0
    else
        # In install mode, show confirmation prompt
        if gum confirm --affirmative="Install" --negative="Cancel" --default=false "Proceed with installation?"; then
            show_header "Installing Packages"
            # Output packages to FD 3 for install.sh to process
            printf "%s\n" "${package_list[@]}" >&3
            exit 0
        fi
    fi
}

# Function to handle menu exit
exit_menu() {
    while true; do
        input=$(gum input --placeholder "Type 'sayonara' to exit..." --cursor.foreground 212)
        if [[ "${input,,}" == "sayonara" ]]; then
            break
        fi
        gum style --foreground 196 "Please type 'sayonara' to exit"
    done
    exit 0
}

# Main menu function
main_menu() {
    while true; do
        show_header "Setupr Installation Menu"
        show_status_bar
        echo

        local menu_options=()
        for cat in "${!CATEGORIES[@]}"; do
            local count="${selected_count[$cat]:-0}"
            if [ "$count" -gt 0 ]; then
                menu_options+=("◆ $cat ($count selected)")
            else
                menu_options+=("◇ $cat")
            fi
        done
        if [ "${#selected_packages[@]}" -gt 0 ]; then
            if [ "$SAVE_CONFIG_MODE" -eq 1 ]; then
                menu_options+=("💾 Save Configuration (${#selected_packages[@]} items)")
            else
                menu_options+=("⚡ Continue to Installation (${#selected_packages[@]} items)")
            fi
        else
            if [ "$SAVE_CONFIG_MODE" -eq 1 ]; then
                menu_options+=("💾 Save Configuration")
            else
                menu_options+=("⚡ Continue to Installation")
            fi
        fi

        # Display menu and get selection
        local choice
        choice=$(printf '%s\n' "${menu_options[@]}" | \
                gum choose --cursor.foreground="212" --selected.foreground="82" \
                --height=$((${#menu_options[@]} + 2))) || continue
        
        # Clean up the selection
        choice=$(echo "$choice" | sed -E 's/ \([^)]+\)$//' | sed 's/^[^[:alnum:]]* //')

        if [[ "$choice" == "Continue to Installation"* ]] || [[ "$choice" == "Save Configuration"* ]]; then
            show_summary_and_install
        else
            select_packages "$choice"
        fi
    done
}

# Parse command line arguments
SAVE_CONFIG_MODE=0
for arg in "$@"; do
    case $arg in
        --save-config)
            SAVE_CONFIG_MODE=1
            shift
            ;;
    esac
done

# Start the script
main_menu
