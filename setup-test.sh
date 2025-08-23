#!/bin/bash

dnf update -y
dnf remove firefox gnome-weather gnome-clocks gnome-contacts cheese gnome-tour gnome-music gnome-calendar yelp xsane totem snapshot firefox epiphany libreoffice-impress libreoffice-writer libreoffice-calc -y

# Setup Conky for autostart
echo "Setting up Conky for autostart..."
# Copy conky config to user's home directory
cp conky.conf ~/.conkyrc

# Create autostart directory if it doesn't exist
mkdir -p ~/.config/autostart

# Create desktop entry for Conky autostart
cat > ~/.config/autostart/conky.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Conky
Comment=System monitor
Exec=conky -c ~/.conkyrc
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

# Make the desktop entry executable
chmod +x ~/.config/autostart/conky.desktop

echo "Conky has been configured to start automatically on login"
