#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root (commented out for debugging)
# if [[ $EUID -ne 0 ]]; then
#     print_error "This script must be run as root"
#     exit 1
# fi

# Check for required tools
if ! command -v xorriso &> /dev/null; then
    print_error "xorriso not found. Install with: dnf install xorriso"
    exit 1
fi

# Find ISO file
ISO_FILE=$(find iso -name "*.iso" -type f | head -1)
if [[ -z "$ISO_FILE" ]]; then
    print_error "No ISO file found in iso/ directory"
    exit 1
fi

print_info "Using ISO: $ISO_FILE"

# Set up directories
TEMP_DIR="/tmp/test_iso_$$"
MOUNT_POINT="/tmp/iso_mount_$$"
OUTPUT_DIR="output"

mkdir -p "$TEMP_DIR" "$MOUNT_POINT" "$OUTPUT_DIR"

print_info "Mounting ISO..."
if sudo mount -o loop "$ISO_FILE" "$MOUNT_POINT"; then
    print_success "ISO mounted"
else
    print_error "Failed to mount ISO"
    exit 1
fi

print_info "Copying ISO contents..."
if cp -r "$MOUNT_POINT"/* "$TEMP_DIR/" 2>/dev/null; then
    print_success "Contents copied"
else
    print_error "Failed to copy contents"
    sudo umount "$MOUNT_POINT"
    exit 1
fi

umount "$MOUNT_POINT"

print_info "ISO directory structure:"
ls -la "$TEMP_DIR" | head -10

# Create simple kickstart
cat > "$TEMP_DIR/test.ks" << 'EOF'
#version=RHEL8
graphical
keyboard --vckeymap=us --xlayouts='us'
lang en_US.UTF-8
network --bootproto=dhcp --device=link --onboot=off --ipv6=auto
cdrom
firstboot --enable
ignoredisk --only-use=sda
autopart --type=lvm
clearpart --none --initlabel
timezone America/New_York --isUtc
rootpw --plaintext testroot
user --groups=wheel --name=testuser --password=testpass --plaintext --gecos="Test User"
%packages
@^workstation-product-environment
%end
reboot
EOF

print_success "Created test kickstart"

# Check boot files
print_info "Looking for boot files..."
if [[ -f "$TEMP_DIR/isolinux/isolinux.bin" ]]; then
    print_info "Found isolinux boot files"
    BOOT_CATALOG="isolinux/isolinux.bin"
elif [[ -f "$TEMP_DIR/syslinux/isolinux.bin" ]]; then
    print_info "Found syslinux boot files"
    BOOT_CATALOG="syslinux/isolinux.bin"
else
    print_error "No boot catalog found"
    find "$TEMP_DIR" -name "*.bin" | head -5
fi

# Get volume ID
VOLUME_ID=$(isoinfo -d -i "$ISO_FILE" | grep "Volume id:" | cut -d' ' -f3- | tr -d ' ')
print_info "Volume ID: $VOLUME_ID"

# Create new ISO
OUTPUT_ISO="$OUTPUT_DIR/test-custom.iso"
print_info "Creating ISO: $OUTPUT_ISO"

XORRISO_CMD="xorriso -as mkisofs -V '$VOLUME_ID' -J -joliet-long -r"

if [[ -n "$BOOT_CATALOG" && -f "$TEMP_DIR/$BOOT_CATALOG" ]]; then
    XORRISO_CMD+=" -b $BOOT_CATALOG -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table"
fi

if [[ -f "$TEMP_DIR/images/efiboot.img" ]]; then
    XORRISO_CMD+=" -eltorito-alt-boot -e images/efiboot.img -no-emul-boot"
fi

XORRISO_CMD+=" -o '$OUTPUT_ISO' '$TEMP_DIR'"

print_info "Command: $XORRISO_CMD"

if eval "$XORRISO_CMD"; then
    print_success "ISO created successfully: $OUTPUT_ISO"
    ls -lh "$OUTPUT_ISO"
else
    print_error "Failed to create ISO"
fi

# Cleanup
print_info "Cleaning up..."
rm -rf "$TEMP_DIR" "$MOUNT_POINT"
print_success "Done"