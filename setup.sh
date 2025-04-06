#!/bin/bash

dnf update -y

sudo dnf install @virtualization

sudo dnf group install --with-optional virtualization

sudo systemctl start libvirtd
#sets the libvirtd service to start on system start
sudo systemctl enable libvirtd

#add current user to virt manager group
sudo usermod -a -G libvirt $(whoami)

sudo rpmkeys --import https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg

printf "[gitlab.com_paulcarroty_vscodium_repo]\nname=download.vscodium.com\nbaseurl=https://download.vscodium.com/rpms/\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg\nmetadata_expire=1h\n" | sudo tee -a /etc/yum.repos.d/vscodium.repo

sudo dnf install codium