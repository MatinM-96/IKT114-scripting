#!/usr/bin/env bash

# Global verbosity flag (default: off)
VERBOSE=false

# Function to print messages only in verbose mode
log() {
    local message="$1"
    local force_output="$2"  # New argument to force output even if VERBOSE is off

    if [[ "$VERBOSE" == "true" || "$force_output" == "true" ]]; then
        echo "[VERBOSE] $1"
    fi
}

# Function to detect OS and determine the package manager
detect_os() {
    log "Detecting operating system..."

    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        case "$ID" in
            debian|ubuntu)
                PACKAGE_MANAGER="apt"
                ;;
            almalinux|fedora|centos|rhel)
                PACKAGE_MANAGER="dnf"
                ;;
            alpine)
                PACKAGE_MANAGER="apk"
                ;;
            *)
                echo "Unsupported OS: $ID"
                exit 1
                ;;
        esac
        log "Detected OS: $ID, using package manager: $PACKAGE_MANAGER"
    else
        echo "Cannot determine the OS. /etc/os-release file is missing."
        exit 1
    fi
}

# Function to remove Docker
remove_docker() {
    log "Removing Docker on $ID using $PACKAGE_MANAGER..."

    case "$PACKAGE_MANAGER" in
        apt)
            log "Removing Docker packages with APT..."
            # The following '|| true' ensures script continues even if a package is not installed
            sudo apt remove -y docker-ce docker-ce-cli containerd.io docker.io 2>/dev/null || true
            sudo apt purge -y docker-ce docker-ce-cli containerd.io docker.io 2>/dev/null || true
            # Remove Docker repository and GPG key if desired:
            sudo rm -f /etc/apt/sources.list.d/docker.list 2>/dev/null
            sudo rm -f /etc/apt/keyrings/docker.gpg 2>/dev/null
            sudo apt update
            ;;
        dnf)
            log "Removing Docker packages with DNF..."
            sudo dnf remove -y docker-ce docker-ce-cli containerd.io 2>/dev/null || true
            # Remove Docker repo if desired:
            sudo rm -f /etc/yum.repos.d/docker-ce.repo 2>/dev/null
            ;;
        apk)
            log "Removing Docker packages with APK..."
            sudo apk del --purge docker 2>/dev/null || true
            ;;
        *)
            echo "Package manager not supported for Docker removal."
            exit 1
            ;;
    esac

    # Stop and disable Docker service if it exists
    log "Disabling and stopping Docker service..."
    sudo systemctl stop docker 2>/dev/null || log "Docker service stop failed (maybe not installed)."
    sudo systemctl disable docker 2>/dev/null || log "Docker service disable failed (maybe not installed)."

    # Clean up Docker directories
    log "Removing Docker directories (/var/lib/docker, /etc/docker)..."
    sudo rm -rf /var/lib/docker
    sudo rm -rf /etc/docker

    echo "Docker removal complete!"
}

# Function to remove Docker Compose (Version 2)
remove_docker_compose() {
    log "Removing Docker Compose..."
    # Docker Compose is typically installed as a single binary in /usr/local/bin
    if [[ -f /usr/local/bin/docker-compose ]]; then
        sudo rm -f /usr/local/bin/docker-compose
        echo "Docker Compose binary removed."
    else
        log "Docker Compose not found."
    fi
}

# Function to remove users
remove_users() {
    log "Removing users..." "true"  # Always display

    for user in "${users_list[@]}"; do
        # Double-check the user exists
        if id "$user" &>/dev/null; then
            log "Removing user '$user'." "true"  # Always print
            # Be cautious: userdel -r removes the user’s home directory, too
            # If you want to keep home directories, remove the '-r' flag
            sudo userdel -r "$user" 2>/dev/null || {
                log "Failed to remove user '$user' or their home directory." "true"
            }
        else
            log "User '$user' does not exist; skipping." "true"
        fi
    done
}

# Function to remove groups
remove_groups() {
    log "Removing groups..." "true"

    for group in "${groups_list[@]}"; do
        # Double-check group exists
        if getent group "$group" &>/dev/null; then
            log "Removing group '$group'." "true"
            sudo groupdel "$group" 2>/dev/null || {
                log "Failed to remove group '$group'." "true"
            }
        else
            log "Group '$group' does not exist; skipping." "true"
        fi
    done
}

# Argument Parsing
users_list=()
groups_list=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --users)
            shift
            IFS=' ' read -r -a users_list <<< "$1"
            shift
            ;;
        --groups)
            shift
            IFS=' ' read -r -a groups_list <<< "$1"
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            log "Warning: Unknown argument '$1' ignored."
            shift
            ;;
    esac
done

# Main
detect_os
remove_docker
remove_docker_compose
remove_users
remove_groups
