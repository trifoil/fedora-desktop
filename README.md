# fedora-desktop

## Creating Installation Media

To create a Fedora desktop installation USB with kickstart configuration:

1. Place your Fedora ISO file(s) in the `iso/` directory
2. Run the ISO writer script as root:

```bash
git clone https://github.com/trifoil/fedora-desktop
cd fedora-desktop
sudo ./isowriter.sh
```

The script will:
- Let you select from available ISO files
- Prompt for username and passwords
- Ask for keyboard layout (French or Belgian)
- Generate a kickstart file with all packages from setup.sh
- Write the ISO to your USB device

## Post-Installation Setup

If you want to manually install packages after a regular Fedora installation:

```bash
git clone https://github.com/trifoil/fedora-desktop
cd fedora-desktop
sudo sh setup.sh
```

## Boot Instructions

When booting from the created USB:
- At the boot prompt, type: `linux ks=hd:LABEL=Fedora-WS-Live-*/fedora-desktop.ks`
- The installation will proceed automatically with your configured settings




Creating a Kickstart Boot CD-ROM

To perform a CD-ROM-based kickstart installation, the kickstart file must be named ks.cfg and must be located in the boot CD-ROM’s top-level directory. Since a CD-ROM is read-only, the file must be added to the directory used to create the image that is written to the CD-ROM. Refer to the Making an Installation Boot CD-ROM section in the Red Hat Enterprise Linux Installation Guide for instruction on creating a boot CD-ROM; however, before making the file.iso image file, copy the ks.cfg kickstart file to the isolinux/ directory.
