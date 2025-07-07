#!/bin/bash
set -euo pipefail

# Load shared functions
source "$(dirname "$0")/utils.sh"

print_header "Nginx Auto Installer"

# Detect OS
OS_ID=$(grep -oP '^ID=\K.*' /etc/os-release | tr -d '"')
case "$OS_ID" in
    ubuntu|debian)
        ;;
    *)
        error "Unsupported OS: $OS_ID"
        exit 1
        ;;
esac

# Get user input
source "$(dirname "$0")/configs.sh"

# Run OS-specific logic
source "$(dirname "$0")/$OS_ID.sh"
