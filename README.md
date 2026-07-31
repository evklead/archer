# Archer - Arch Installation Script

## Description
Simple Arch Linux installation script. Created for personal use. Highly opinionated.

## Features
- Uses BTRFS with snapshots
- Optionally creates HOME FS on a separate block device
- Optionally enables LUKS and stores encryption keys in the TPM device
- Installs `nvidia-open` driver if NVIDIA GPU is detected in the system
- Creates a Pacman hook for automated snapshotting before each installation or upgrade
- Creates a snapshot immediately after the installation is complete, so the system may later be rolled back to the freshly installed state
- May be used to install KDE Plasma desktop environment straight away
- May be easilly customized to install any other desktop environment and/or any other additional packages

## How to use
1. Use Arch Linux ISO image to boot: https://archlinux.org/download/
2. Connect to the internet: https://wiki.archlinux.org/title/Installation_guide#Connect_to_the_internet
3. Install git:
```
pacman -Sy
pacman -S git
```
4. clone the repo ( for instance, to `/opt` ):
```
cd /opt
git clone https://github.com/evklead/archer.git
cd archer
```
5. Run the installer script
```
./install.sh
```
6. Follow the script prompts
7. Reboot and enjoy

## Customization
- The script may be used without any modifications to install the base system and the desktop environment.
- Packages installed on the first phase of installation are listed in `pacstrap_list.txt`. This file may be edited to adjust the list of required packages.
- Systemd services enabled by the installer are listed in `top-off/services.txt`. This file may be edited to adjust the list of services being enabled.
- The desktop environment installation is defined by the list of packages in `top-off/desktop_list.txt`. This file may be edited to change the desktop environment and its components.
- If the desktop environment is installed, then all Systemd services listed in `top-off/desktop_services.txt` will be enabled. Adjust as needed.
- Everything from `top-off/usercontent/home` will be copied to the home directory of the user created by the installer.
- The installer will run any scripts added to `top-off/usercontent/scripts`

## Limitations and known issues
- At this point, the installer works with UEFI systems only
- In some situations, the installation may fail on the BTRFS creation step, because of the race condition after re-partitioning of block devices.

