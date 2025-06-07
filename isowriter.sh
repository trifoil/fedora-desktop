#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Debug logging level (0=quiet, 1=normal, 2=verbose, 3=debug)
DEBUG=3

# Function to print debug output
debug() {
    if [[ $DEBUG -ge 3 ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Function to print verbose output
verbose() {
    if [[ $DEBUG -ge 2 ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Function to print colored output
print_info() {
    if [[ $DEBUG -ge 1 ]]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

print_success() {
    if [[ $DEBUG -ge 1 ]]; then
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    fi
}

print_warning() {
    if [[ $DEBUG -ge 1 ]]; then
        echo -e "${YELLOW}[WARNING]${NC} $1"
    fi
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running as root
check_root() {
    debug "Checking if running as root..."
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
    debug "Root check passed"
}

# Function to check required tools
check_tools() {
    debug "Checking for required tools..."
    local missing_tools=()
    
    for tool in xorriso isoinfo python3; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
            debug "Missing tool: $tool"
        else
            debug "Found tool: $tool"
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_info "Install them with: dnf install xorriso isomd5sum python3"
        exit 1
    fi
    debug "All required tools are available"
}

# Function to select ISO file
select_iso() {
    debug "Starting ISO selection..."
    local iso_dir="iso"
    
    if [[ ! -d "$iso_dir" ]]; then
        mkdir -p "$iso_dir"
        print_warning "Created ISO directory '$iso_dir'"
        print_info "Please place your Fedora ISO files in the 'iso' directory and run again."
        exit 1
    fi
    
    # Find ISO files
    debug "Searching for ISO files in $iso_dir"
    mapfile -t iso_files < <(find "$iso_dir" -name "*.iso" -type f 2>/dev/null)
    
    if [[ ${#iso_files[@]} -eq 0 ]]; then
        print_error "No ISO files found in '$iso_dir' directory!"
        print_info "Please place your Fedora ISO files in the 'iso' directory."
        exit 1
    fi
    
    echo
    print_info "Available ISO files:"
    for i in "${!iso_files[@]}"; do
        echo "$((i+1))) $(basename "${iso_files[$i]}")"
    done
    echo "$((${#iso_files[@]}+1))) Exit"
    
    while true; do
        echo
        read -p "Select an ISO file (1-$((${#iso_files[@]}+1))): " choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le $((${#iso_files[@]}+1)) ]]; then
            if [[ "$choice" -eq $((${#iso_files[@]}+1)) ]]; then
                print_info "Exiting..."
                exit 0
            else
                selected_iso="${iso_files[$((choice-1))]}"
                print_success "Selected: $(basename "$selected_iso")"
                debug "Selected ISO path: $selected_iso"
                break
            fi
        else
            print_error "Invalid selection. Please try again."
        fi
    done
}

# Function to get user input
get_user_input() {
    debug "Starting user input collection..."
    echo
    print_info "Setting up installation parameters..."
    
    # Get username
    while true; do
        read -p "Enter username: " username
        if [[ -n "$username" ]] && [[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
            debug "Username set to: $username"
            break
        else
            print_error "Invalid username. Use lowercase letters, numbers, underscore, and hyphen only."
        fi
    done
    
    # Get user password
    while true; do
        read -s -p "Enter user password: " user_password
        echo
        read -s -p "Confirm user password: " user_password_confirm
        echo
        if [[ "$user_password" == "$user_password_confirm" ]] && [[ -n "$user_password" ]]; then
            debug "User password confirmed"
            break
        else
            print_error "Passwords don't match or are empty. Please try again."
        fi
    done
    
    # Get root password
    while true; do
        read -s -p "Enter root password: " root_password
        echo
        read -s -p "Confirm root password: " root_password_confirm
        echo
        if [[ "$root_password" == "$root_password_confirm" ]] && [[ -n "$root_password" ]]; then
            debug "Root password confirmed"
            break
        else
            print_error "Passwords don't match or are empty. Please try again."
        fi
    done
    
    # Get disk encryption password
    while true; do
        read -s -p "Enter disk encryption password: " encryption_password
        echo
        read -s -p "Confirm disk encryption password: " encryption_password_confirm
        echo
        if [[ "$encryption_password" == "$encryption_password_confirm" ]] && [[ -n "$encryption_password" ]]; then
            debug "Encryption password confirmed"
            break
        else
            print_error "Passwords don't match or are empty. Please try again."
        fi
    done
    
    # Get keyboard layout
    echo
    print_info "Select keyboard layout:"
    echo "1) French"
    echo "2) Belgian"
    echo "3) US (default)"
    
    while true; do
        read -p "Select keyboard layout (1-3): " kb_choice
        case $kb_choice in
            1)
                keyboard_layout="fr"
                keyboard_variant="oss"
                print_success "Selected: French keyboard layout"
                debug "Keyboard layout set to: $keyboard_layout with variant $keyboard_variant"
                break
                ;;
            2)
                keyboard_layout="be"
                keyboard_variant=""
                print_success "Selected: Belgian keyboard layout"
                debug "Keyboard layout set to: $keyboard_layout"
                break
                ;;
            3)
                keyboard_layout="us"
                keyboard_variant=""
                print_success "Selected: US keyboard layout"
                debug "Keyboard layout set to: $keyboard_layout"
                break
                ;;
            *)
                print_error "Invalid selection. Please choose 1, 2 or 3."
                ;;
        esac
    done
}

# Function to create kickstart file
create_kickstart() {
    local ks_file="$1/fedora-desktop.ks"
    
    print_info "Creating kickstart file..."
    debug "Kickstart file location: $ks_file"
    
    # Generate password hashes
    debug "Generating password hashes..."
    local root_pw_hash=$(python3 -c "import crypt; print(crypt.crypt('$root_password', crypt.mksalt(crypt.METHOD_SHA512)))" 2>/dev/null)
    local user_pw_hash=$(python3 -c "import crypt; print(crypt.crypt('$user_password', crypt.mksalt(crypt.METHOD_SHA512)))" 2>/dev/null)
    
    if [[ -z "$root_pw_hash" || -z "$user_pw_hash" ]]; then
        print_error "Failed to generate password hashes!"
        debug "Python command output:"
        python3 -c "import crypt; print(crypt.crypt('test', crypt.mksalt(crypt.METHOD_SHA512)))" 2>&1 | debug
        return 1
    fi
    
    debug "Creating kickstart content..."
    cat > "$ks_file" << EOF
#version=FEDORA42
# Use graphical install
graphical

# Keyboard layouts
keyboard --vckeymap=$keyboard_layout --xlayouts='$keyboard_layout$([[ -n "$keyboard_variant" ]] && echo "($keyboard_variant)")'
# System language
lang en_US.UTF-8

# Network information
network --bootproto=dhcp --device=link --onboot=off --ipv6=auto --no-activate
network --hostname=fedora-desktop

# Use CDROM installation media
cdrom

# Run the Setup Agent on first boot
firstboot --enable

# Generated using Blivet version 3.4.0
ignoredisk --only-use=sda
autopart --type=lvm --encrypted --passphrase=$encryption_password
# Partition clearing information
clearpart --none --initlabel

# System timezone
timezone America/New_York --isUtc

# Root password
rootpw --iscrypted $root_pw_hash

# User creation
user --groups=wheel --name=$username --password=$user_pw_hash --iscrypted --gecos="$username"

%packages
@^workstation-product-environment
@base
@core
@desktop-debugging
@dial-up
@fonts
@guest-desktop-agents
@hardware-support
@multimedia
@networkmanager-submodules
@printing
@workstation-product
@virtualization
seahorse
rustup
cargo
texlive-scheme-full
libreoffice
texstudio
deluge
inkscape
blender
krita
helvum
btop
fastfetch
conky
wine
winetricks
hydrapaper
cockpit
docker-ce
docker-ce-cli
containerd.io
docker-buildx-plugin
docker-compose-plugin
codium
%end

%addon com_redhat_kdump --disable --reserve-mb='128'
%end

%anaconda
pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
%end

%post --log=/root/ks-post.log

# Update system
dnf update -y

# Remove unwanted packages
dnf remove firefox gnome-weather gnome-clocks gnome-contacts cheese gnome-tour gnome-music gnome-calendar yelp xsane totem snapshot gnome-software firefox epiphany libreoffice-impress libreoffice-writer libreoffice-calc -y

# Install virtualization
dnf install @virtualization -y
dnf group install --with-optional virtualization -y
systemctl start libvirtd
systemctl enable libvirtd
usermod -a -G libvirt $username

# Install additional packages
dnf install seahorse -y
dnf install rustup cargo -y
dnf install texlive-scheme-full -y
dnf install libreoffice -y
dnf install texstudio -y
dnf install deluge -y
dnf install inkscape -y
dnf install blender -y
dnf install krita -y
dnf install helvum btop fastfetch conky wine winetricks -y
dnf install hydrapaper -y

# Setup Cockpit
dnf install cockpit -y
systemctl enable --now cockpit.socket
firewall-cmd --add-service=cockpit
firewall-cmd --add-service=cockpit --permanent

# Remove old Docker packages
dnf remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine -y

# Install Docker
dnf -y install dnf-plugins-core 
dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo 
dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
systemctl enable --now docker
usermod -a -G docker $username

# Install VSCodium
rpmkeys --import https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg
printf "[gitlab.com_paulcarroty_vscodium_repo]\nname=download.vscodium.com\nbaseurl=https://download.vscodium.com/rpms/\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg\nmetadata_expire=1h\n" | tee -a /etc/yum.repos.d/vscodium.repo
dnf install codium -y

# Install Flatpak applications
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub org.videolan.VLC -y
flatpak install flathub com.rustdesk.RustDesk -y
flatpak install flathub dev.zed.Zed -y
flatpak install flathub io.github.shiftey.Desktop -y
flatpak install flathub com.simulide.simulide -y
flatpak install flathub cc.arduino.IDE2 -y
flatpak install flathub org.inkscape.Inkscape -y
flatpak install flathub com.boxy_svg.BoxySVG -y
flatpak install flathub org.torproject.torbrowser-launcher -y
flatpak install flathub org.tenacityaudio.Tenacity -y
flatpak install flathub nl.hjdskes.gcolor3 -y
flatpak install flathub io.gitlab.librewolf-community -y
flatpak install flathub com.github.xournalpp.xournalpp -y
flatpak install flathub com.mattjakeman.ExtensionManager -y
flatpak install flathub org.wireshark.Wireshark -y
flatpak install flathub com.github.unrud.VideoDownloader -y
flatpak install flathub io.github.vmkspv.netsleuth -y
flatpak install flathub de.capypara.FieldMonitor -y
flatpak install flathub com.logseq.Logseq -y
flatpak install flathub org.gimp.GIMP -y
flatpak install flathub fr.romainvigier.MetadataCleaner -y
flatpak install flathub im.nheko.Nheko -y
flatpak install flathub io.github.bytezz.IPLookup -y
flatpak install flathub net.waterfox.waterfox -y
flatpak install flathub org.freecad.FreeCAD -y

echo "Post-installation script completed successfully!" >> /root/ks-post.log

%end

reboot
EOF

    if [[ $? -eq 0 ]]; then
        print_success "Kickstart file created: $ks_file"
        debug "Kickstart file contents:"
        [[ $DEBUG -ge 3 ]] && head -n 20 "$ks_file" | debug
        return 0
    else
        print_error "Failed to create kickstart file"
        debug "Last command exit code: $?"
        return 1
    fi
}

# Function to modify boot configuration
modify_boot_config() {
    local temp_dir="$1"
    
    print_info "Modifying boot configuration..."
    debug "Working directory: $temp_dir"
    
    # Get ISO label
    local iso_label=$(isoinfo -d -i "$selected_iso" | grep "Volume id:" | cut -d' ' -f3- | tr -d "'" | tr ' ' '_')
    if [[ -z "$iso_label" ]]; then
        iso_label="FEDORA_CUSTOM"
        print_warning "Could not determine ISO label, using default: $iso_label"
    else
        debug "Detected ISO label: $iso_label"
    fi
    
    # Check for boot configuration files
    debug "Searching for boot configuration files..."
    find "$temp_dir" -name "*.cfg" -o -name "*.txt" | while read -r file; do
        debug "Found boot config file: $file"
    done
    
    # Modify GRUB configuration for UEFI
    local grub_cfg="$temp_dir/EFI/BOOT/grub.cfg"
    if [[ -f "$grub_cfg" ]]; then
        debug "Found UEFI grub.cfg at $grub_cfg"
        debug "Original grub.cfg content (first 10 lines):"
        [[ $DEBUG -ge 3 ]] && head -n 10 "$grub_cfg" | debug
        
        if sed -i "s|quiet|inst.ks=cdrom:/fedora-desktop.ks quiet|g" "$grub_cfg"; then
            print_success "Modified UEFI boot configuration"
            debug "Modified grub.cfg content (first 10 lines):"
            [[ $DEBUG -ge 3 ]] && head -n 10 "$grub_cfg" | debug
        else
            print_error "Failed to modify UEFI grub.cfg"
            debug "sed command failed with exit code $?"
            return 1
        fi
    else
        print_warning "UEFI grub.cfg not found at $grub_cfg"
        debug "UEFI boot configuration files:"
        [[ $DEBUG -ge 3 ]] && find "$temp_dir/EFI" -type f | debug
    fi
    
    # Modify isolinux configuration for BIOS
    local isolinux_cfg="$temp_dir/isolinux/isolinux.cfg"
    if [[ -f "$isolinux_cfg" ]]; then
        debug "Found BIOS isolinux.cfg at $isolinux_cfg"
        debug "Original isolinux.cfg content (first 10 lines):"
        [[ $DEBUG -ge 3 ]] && head -n 10 "$isolinux_cfg" | debug
        
        if sed -i "s|quiet|inst.ks=cdrom:/fedora-desktop.ks quiet|g" "$isolinux_cfg"; then
            print_success "Modified BIOS boot configuration"
            debug "Modified isolinux.cfg content (first 10 lines):"
            [[ $DEBUG -ge 3 ]] && head -n 10 "$isolinux_cfg" | debug
        else
            print_error "Failed to modify BIOS isolinux.cfg"
            debug "sed command failed with exit code $?"
            return 1
        fi
    else
        print_warning "isolinux.cfg not found at $isolinux_cfg"
        debug "BIOS boot configuration files:"
        [[ $DEBUG -ge 3 ]] && find "$temp_dir/isolinux" -type f 2>/dev/null | debug
    fi
    
    # Modify syslinux configuration if present
    local syslinux_cfg="$temp_dir/syslinux/syslinux.cfg"
    if [[ -f "$syslinux_cfg" ]]; then
        debug "Found syslinux.cfg at $syslinux_cfg"
        if sed -i "s|quiet|inst.ks=cdrom:/fedora-desktop.ks quiet|g" "$syslinux_cfg"; then
            print_success "Modified syslinux configuration"
        else
            print_error "Failed to modify syslinux.cfg"
            return 1
        fi
    fi
    
    # Ensure ks.cfg is accessible
    if [[ ! -f "$temp_dir/fedora-desktop.ks" ]]; then
        print_error "Kickstart file not found in ISO root!"
        debug "Contents of ISO root:"
        [[ $DEBUG -ge 3 ]] && ls -la "$temp_dir" | debug
        return 1
    fi
    
    return 0
}

# Function to create custom ISO
create_custom_iso() {
    local temp_dir="$1"
    local output_dir="$2"
    local iso_name="fedora-desktop-custom-$(date +%Y%m%d).iso"
    local output_iso="$output_dir/$iso_name"
    
    print_info "Creating custom ISO..."
    debug "Source directory: $temp_dir"
    debug "Output ISO: $output_iso"
    
    # Get the original ISO information
    local volume_id=$(isoinfo -d -i "$selected_iso" | grep "Volume id:" | cut -d' ' -f3-)
    if [[ -z "$volume_id" ]]; then
        volume_id="FEDORA_CUSTOM"
        print_warning "Could not determine original volume ID, using default: $volume_id"
    else
        # Clean up volume ID to comply with ISO 9660 standards
        volume_id=$(echo "$volume_id" | tr ' ' '_' | cut -c1-32)
        debug "Original volume ID: $volume_id (after cleanup)"
    fi
    
    # Check for boot catalog locations - this is the critical fix
    local bios_boot_catalog=""
    local uefi_boot_img=""
    
    # First check standard locations for boot files
    if [[ -f "$temp_dir/isolinux/isolinux.bin" ]]; then
        bios_boot_catalog="isolinux/isolinux.bin"
        debug "Found BIOS boot catalog in isolinux directory"
    elif [[ -f "$temp_dir/boot/isolinux/isolinux.bin" ]]; then
        bios_boot_catalog="boot/isolinux/isolinux.bin"
        debug "Found BIOS boot catalog in boot/isolinux directory"
    elif [[ -f "$temp_dir/images/boot.iso" ]]; then
        # Some Fedora ISOs have the boot image here
        bios_boot_catalog="images/boot.iso"
        debug "Found BIOS boot catalog in images directory"
    fi
    
    # Check for UEFI boot images
    if [[ -f "$temp_dir/EFI/BOOT/BOOTX64.EFI" ]]; then
        uefi_boot_img="EFI/BOOT/BOOTX64.EFI"
        debug "Found UEFI boot image"
    elif [[ -f "$temp_dir/images/efiboot.img" ]]; then
        uefi_boot_img="images/efiboot.img"
        debug "Found UEFI boot image in images directory"
    fi
    
    # Prepare xorriso command
    local xorriso_cmd="xorriso -as mkisofs \
        -volid \"$volume_id\" \
        -J -joliet-long -r \
        -iso-level 3"
    
    # Only add BIOS boot options if we found the components
    if [[ -n "$bios_boot_catalog" ]]; then
        xorriso_cmd+=" -b \"$bios_boot_catalog\" \
        -c \"isolinux/boot.cat\" \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table"
        debug "Added BIOS boot options to xorriso command"
    else
        print_warning "No BIOS boot components found - creating non-bootable ISO"
    fi
    
    # Only add UEFI boot options if we found the components
    if [[ -n "$uefi_boot_img" ]]; then
        xorriso_cmd+=" -eltorito-alt-boot \
        -e \"$uefi_boot_img\" \
        -no-emul-boot"
        debug "Added UEFI boot options to xorriso command"
    fi
    
    # Only add hybrid options if we have boot components
    if [[ -n "$bios_boot_catalog" && -f "/usr/share/syslinux/isohdpfx.bin" ]]; then
        xorriso_cmd+=" -isohybrid-mbr /usr/share/syslinux/isohdpfx.bin \
        -isohybrid-gpt-basdat"
        debug "Added hybrid boot options to xorriso command"
    fi
    
    xorriso_cmd+=" -o \"$output_iso\" \
        \"$temp_dir\""
    
    debug "Full xorriso command:"
    debug "$xorriso_cmd"
    
    # Execute the command with full output
    print_info "Running ISO creation command..."
    eval "$xorriso_cmd"
    local xorriso_status=$?
    
    if [[ $xorriso_status -eq 0 ]]; then
        print_success "Custom ISO created: $output_iso"
        
        # Verify ISO was created
        if [[ ! -f "$output_iso" ]]; then
            print_error "ISO file not found at expected location: $output_iso"
            return 1
        fi
        
        # Make ISO hybrid if we have the components
        if [[ -n "$bios_boot_catalog" ]] && command -v isohybrid &>/dev/null; then
            print_info "Making ISO hybrid for USB booting..."
            isohybrid "$output_iso" 2>/dev/null || print_warning "isohybrid failed but ISO was created"
        fi
        
        # Add MD5 checksum if available
        if command -v implantisomd5 &>/dev/null; then
            print_info "Adding MD5 checksum to ISO..."
            implantisomd5 "$output_iso" 2>/dev/null || print_warning "MD5 implant failed but ISO was created"
        fi
        
        print_success "ISO is ready for writing to USB drive"
        echo
        print_info "To write to USB drive, use:"
        print_info "sudo dd if='$output_iso' of=/dev/sdX bs=4M status=progress && sync"
        print_info "(Replace sdX with your USB device, e.g., sdb)"
        
        return 0
    else
        print_error "Failed to create custom ISO (xorriso exit code: $xorriso_status)"
        return 1
    fi
}

# Function to extract and modify ISO
extract_and_modify_iso() {
    local temp_dir="/tmp/fedora_custom_$$"
    local mount_point="/tmp/iso_mount_$$"
    local output_dir="output"
    
    # Cleanup any previous runs
    debug "Cleaning up previous runs..."
    umount "$mount_point" 2>/dev/null || true
    rm -rf "$temp_dir" "$mount_point" 2>/dev/null || true
    
    # Create directories
    debug "Creating working directories..."
    mkdir -p "$temp_dir" "$mount_point" "$output_dir"
    debug "Created directories:"
    debug "- Temp dir: $temp_dir"
    debug "- Mount point: $mount_point"
    debug "- Output dir: $output_dir"
    
    print_info "Mounting ISO..."
    debug "Mount command: mount -o loop \"$selected_iso\" \"$mount_point\""
    
    # Mount the ISO
    if mount -o loop "$selected_iso" "$mount_point"; then
        print_success "ISO mounted successfully"
        debug "Mounted ISO contents:"
        [[ $DEBUG -ge 3 ]] && ls -la "$mount_point" | head -n 10 | debug
    else
        print_error "Failed to mount ISO"
        debug "mount command output:"
        [[ $DEBUG -ge 3 ]] && mount -o loop "$selected_iso" "$mount_point" 2>&1 | debug
        return 1
    fi
    
    print_info "Copying ISO contents..."
    debug "Copy command: cp -r \"$mount_point\"/* \"$temp_dir/\""
    
    # Copy all files from ISO
    if cp -r "$mount_point"/* "$temp_dir/"; then
        print_success "ISO contents copied"
        debug "Copied files count: $(find "$temp_dir" -type f | wc -l)"
    else
        print_error "Failed to copy ISO contents"
        debug "cp command exit code: $?"
        debug "Partial copy results:"
        [[ $DEBUG -ge 3 ]] && ls -la "$temp_dir" | debug
        umount "$mount_point"
        return 1
    fi
    
    # Unmount the ISO
    debug "Unmounting ISO..."
    if umount "$mount_point"; then
        debug "ISO unmounted successfully"
    else
        print_warning "Failed to unmount ISO (exit code: $?)"
    fi
    
    # Create kickstart file in the extracted directory
    if ! create_kickstart "$temp_dir"; then
        print_error "Failed to create kickstart file"
        return 1
    fi
    
    # Modify boot configuration
    if ! modify_boot_config "$temp_dir"; then
        print_error "Failed to modify boot configuration"
        return 1
    fi
    
    # Create the new ISO
    if ! create_custom_iso "$temp_dir" "$output_dir"; then
        print_error "Failed to create custom ISO"
        return 1
    fi
    
    # Cleanup
    print_info "Cleaning up temporary files..."
    debug "Removing: $temp_dir $mount_point"
    rm -rf "$temp_dir" "$mount_point"
    print_success "Cleanup completed"
    
    return 0
}

# Main function
main() {
    echo
    print_info "Fedora Desktop Custom ISO Creator"
    echo "================================="
    
    check_root
    check_tools
    select_iso
    get_user_input
    
    if extract_and_modify_iso; then
        echo
        print_success "Custom ISO creation completed successfully!"
        print_info "Your custom ISO is ready in the 'output' directory"
    else
        echo
        print_error "Custom ISO creation failed!"
        debug "Last command exit code: $?"
    fi
    
    echo
}

# Run main function with cleanup trap
trap "cleanup" EXIT
cleanup() {
    debug "Running cleanup..."
    # Unmount any mounted points
    for mount in /tmp/iso_mount_*; do
        if [[ -d "$mount" ]]; then
            debug "Unmounting $mount"
            umount "$mount" 2>/dev/null || true
            rmdir "$mount" 2>/dev/null || true
        fi
    done
    
    # Remove temp directories
    for temp in /tmp/fedora_custom_*; do
        if [[ -d "$temp" ]]; then
            debug "Removing $temp"
            rm -rf "$temp" 2>/dev/null || true
        fi
    done
}

main "$@"