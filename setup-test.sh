#!/bin/bash

# Update system
dnf update -y

# Remove unnecessary packages
dnf remove -y firefox gnome-weather gnome-clocks gnome-contacts cheese gnome-tour gnome-music gnome-calendar yelp xsane totem snapshot epiphany libreoffice-impress libreoffice-writer libreoffice-calc

# Get the real user's home directory
USER_HOME=$(eval echo "~$SUDO_USER")

echo "Setting up Conky for autostart..."

# Copy conky config to user's home directory
cp conky.conf "$USER_HOME/.conkyrc"
chown $SUDO_USER:$SUDO_USER "$USER_HOME/.conkyrc"

# Create autostart directory if it doesn't exist
mkdir -p "$USER_HOME/.config/autostart"
chown -R $SUDO_USER:$SUDO_USER "$USER_HOME/.config"

# Create desktop entry for Conky autostart
cat > "$USER_HOME/.config/autostart/conky.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Conky
Comment=System monitor
Exec=conky -c ~/.conkyrc
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

# Make the desktop entry executable
chmod +x "$USER_HOME/.config/autostart/conky.desktop"
chown $SUDO_USER:$SUDO_USER "$USER_HOME/.config/autostart/conky.desktop"

echo "Conky has been configured to start automatically on login for $SUDO_USER."
