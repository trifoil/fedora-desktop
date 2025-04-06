#!/bin/bash

dnf update -y

sudo dnf install @virtualization

sudo dnf group install --with-optional virtualization

sudo systemctl start libvirtd
#sets the libvirtd service to start on system start
sudo systemctl enable libvirtd

#add current user to virt manager group
sudo usermod -a -G libvirt $(whoami)