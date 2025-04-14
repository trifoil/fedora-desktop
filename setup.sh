#!/bin/bash

dnf update -y
dnf remove firefox gnome-weather
gnome-clocks gnome-contacts cheese gnome-tour gnome-music gnome-calendar yelp xsane totem snapshot gnome-software firefox epiphany libreoffice-impress libreoffice-writer libreoffice-calc -y

dnf install @virtualization -y
dnf group install --with-optional virtualization -y
systemctl start libvirtd 
systemctl enable libvirtd
usermod -a -G libvirt $(whoami)

sudo dnf install rustup cargo -y
dnf install texlive-scheme-full libreoffice texstudio deluge freecad inkscape blender -y
dnf install krita -y
dnf install helvum btop fastfetch conky wine winetricks -y
sudo dnf install hydrapaper -y
    
flatpak install flathub org.videolan.VLC -y
flatpak install rustdesk -y
flatpak install zed -y
flatpak install io.github.shiftey.Desktop -y
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

dnf remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine -y
dnf -y install dnf-plugins-core
dnf-3 config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
