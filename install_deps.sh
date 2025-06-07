#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        print_info "Please run: sudo $0"
        exit 1
    fi
}

print_info "Installing dependencies for Fedora Custom ISO Creator"
echo "===================================================="

check_root

# Update package database
print_info "Updating package database..."
dnf update -y

# Install required packages
print_info "Installing genisoimage and syslinux..."
if dnf install genisoimage syslinux -y; then
    print_success "Dependencies installed successfully!"
else
    print_error "Failed to install dependencies"
    exit 1
fi

# Verify installation
print_info "Verifying installation..."
missing_tools=()

for tool in genisoimage isohybrid; do
    if ! command -v "$tool" &> /dev/null; then
        missing_tools+=("$tool")
    fi
done

if [[ ${#missing_tools[@]} -eq 0 ]]; then
    print_success "All required tools are now available!"
    echo
    print_info "You can now run the ISO creator script: ./isowriter.sh"
else
    print_error "Some tools are still missing: ${missing_tools[*]}"
    exit 1
fi