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
