#!/bin/bash
# Copyright (c) 2012 Tom Wambold
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# This script will set up an Arch installation with a 100 MB /boot partition
# and an encrypted LVM partition with swap and / inside.  It also installs
# and configures systemd as the init system (removing sysvinit).
#
# You should read through this script before running it in case you want to
# make any modifications, in particular, the variables just below, and the
# following functions:
#
#    partition_drive - Customize to change partition sizes (/boot vs LVM)
#    setup_lvm - Customize for partitions inside LVM
#    install_packages - Customize packages installed in base system
#                       (desktop environment, etc.)
#    install_aur_packages - More packages after packer (AUR helper) is
#                           installed
#    set_netcfg - Preload netcfg profiles

## CONFIGURE THESE VARIABLES
## ALSO LOOK AT THE install_packages FUNCTION TO SEE WHAT IS ACTUALLY INSTALLED

# Drive to install to.
DRIVE='/dev/sda'

# Hostname of the installed machine.
HOSTNAME='host100'

# Root password (leave blank to be prompted).
ROOT_PASSWORD='a'

# Main user to create (by default, added to wheel group, and others).
USER_NAME='user'

# The main user's password (leave blank to be prompted).
USER_PASSWORD='a'

# System timezone.
TIMEZONE='Europe/Warsaw'

KEYMAP='pl'
# KEYMAP='dvorak'

# Choose your video driver
# For Intel
VIDEO_DRIVER="i915"
# For nVidia
#VIDEO_DRIVER="nouveau"
# For ATI
#VIDEO_DRIVER="radeon"
# For generic stuff
#VIDEO_DRIVER="vesa"

setup() {
    local boot="$DRIVE"1
    local swap="$DRIVE"2
    local root="$DRIVE"3

    echo 'Creating partitions'
    partition_drive "$DRIVE"

    echo 'Formatting filesystems'
    format_filesystems "$boot" "$swap" "$root"

    echo 'Mounting filesystems'
    mount_filesystems "$boot" "$swap" "$root"
    
    echo 'Installing base system'
    install_base

    echo 'Setting fstab'
    set_fstab

    echo 'Chrooting into installed system to continue setup...'
    cp $0 /mnt/setup.sh
    arch-chroot /mnt ./setup.sh chroot

    if [ -f /mnt/setup.sh ]
    then
        echo 'ERROR: Something failed inside the chroot, not unmounting filesystems so you can investigate.'
        echo 'Make sure you unmount everything before you try to run this script again.'
    else
        echo 'Unmounting filesystems'
        unmount_filesystems "$swap"
        echo 'Done! Reboot system.'
    fi
}

configure() {
    local boot="$DRIVE"1
    local swap="$DRIVE"2
    local root="$DRIVE"3

    echo 'Applying config changes and fixes'
    config_and_fixes

    echo 'Installing additional packages'
    install_packages

    echo 'Installing YAY'
    install_yay

    echo 'Installing AUR packages'
    install_aur_packages

    echo 'Clearing package tarballs'
    clean_packages

    echo 'Updating pkgfile database'
    update_pkgfile

    echo 'Setting hostname'
    set_hostname "$HOSTNAME"

    echo 'Setting timezone'
    set_timezone "$TIMEZONE"

    echo 'Setting locale'
    set_locale

    echo 'Setting console keymap'
    set_keymap

    echo 'Setting hosts file'
    set_hosts "$HOSTNAME"

    #echo 'Setting initial modules to load'
    #set_modules_load

    echo 'Setting initial daemons'
    set_daemons

    echo 'Configuring bootloader'
    set_grub

    echo 'Configuring sudo'
    set_sudoers

    if [ -z "$ROOT_PASSWORD" ]
    then
        echo 'Enter the root password:'
        stty -echo
        read ROOT_PASSWORD
        stty echo
    fi
    echo 'Setting root password'
    set_root_password "$ROOT_PASSWORD"

    if [ -z "$USER_PASSWORD" ]
    then
        echo "Enter the password for user $USER_NAME"
        stty -echo
        read USER_PASSWORD
        stty echo
    fi
    echo 'Creating initial user'
    create_user "$USER_NAME" "$USER_PASSWORD"

    echo 'Building locate database'
    update_locate

    rm /setup.sh
}

partition_drive() {
    local dev="$1"; shift

    # 1000 MB /boot partition, 8000MB swap and rest for the system
    parted -s "$dev" \
        mklabel gpt \
        mkpart boot fat32 1 1000M \
        mkpart swap linux-swap 1000M 9000M \
	mkpart arch ext4 9000M 100% \
        set 1 esp on \
        set 2 swap on \
	set 3 root on
}

format_filesystems() {
    local boot="$1"; shift
    local swap="$1"; shift
    local root="$1"; shift

    mkfs.fat -F32 "$boot"
    mkswap "$swap"
    mkfs.ext4 "$root"
}

mount_filesystems() {
    local boot="$1"; shift
    local swap="$1"; shift
    local root="$1"; shift

    mount "$root" /mnt
    mkdir /mnt/boot
    mount "$boot" /mnt/boot
    swapon "$swap"
}

install_base() {
    reflector --country 'Poland,' --latest 5 --sort rate --save /etc/pacman.d/mirrorlist

    # Enable Paralel downloads for faster downloads (the same is applied after chroot)
    sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/systemd/system.conf

    pacstrap -K /mnt base base-devel linux-firmware linux-zen linux-zen-headers networkmanager grub efibootmgr vim man-db man-pages
}

set_fstab() {
    genfstab -U /mnt >> /mnt/etc/fstab
}

unmount_filesystems() {
    local swap="$1"; shift
    
    umount /mnt/boot
    umount /mnt
    swapoff "$swap"
}

config_and_fixes() {
    hwclock --systohc
    
    # Fix long shutdowns
    sed -i 's/#DefaultTimeoutStopSec.*/DefaultTimeoutStopSec=15s/' /etc/systemd/system.conf

    # Enable Colors and Parallel Downloads in pacman
    sed -i 's/#Color/Color/' /etc/systemd/system.conf
    sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/systemd/system.conf
}

install_packages() {
    local packages=''

    # General utilities/libraries
    packages+=' alsa-utils aspell-en curl cpupower cronie git ntp openssh pkgfile powertop rfkill rsync'

    # Development packages
    #packages+=' apache-ant cmake gdb git maven mercurial subversion tcpdump valgrind wireshark-gtk'

    # Files systems acces
    packages+=' ntfs-3g mtools dosfstools ntfsprogs'

    # Archive tools
    packages+=' p7zip unrar unzip zip'
    
    # Netcfg
    packages+=' ifplugd dialog wireless_tools wpa_actiond'

    # Misc programs
    packages+=' vlc xscreensaver gparted'

    # Xserver
    packages+=' xorg-apps xorg-server xorg-xinit'

    # Fonts
    packages+=' ttf-dejavu ttf-liberation'

    # On Intel processors
    packages+=' intel-ucode'

    # For laptops
    packages+=' xf86-input-synaptics'

    if [ "$VIDEO_DRIVER" = "i915" ]
    then
        packages+=' xf86-video-intel libva-intel-driver'
    elif [ "$VIDEO_DRIVER" = "nouveau" ]
    then
        packages+=' xf86-video-nouveau'
    elif [ "$VIDEO_DRIVER" = "radeon" ]
    then
        packages+=' xf86-video-ati'
    elif [ "$VIDEO_DRIVER" = "vesa" ]
    then
        packages+=' xf86-video-vesa'
    fi

    pacman -Sy --noconfirm $packages
}

install_yay() {
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    makepkg -si --noconfirm --asroot

    cd ..
    rm -rf yay-bin
}

install_aur_packages() {
    yay -Sy --noconfirm yay-bin onlyoffice-bin floorp-bin --aur
}

clean_packages() {
    yes | pacman -Scc
}

update_pkgfile() {
    pkgfile -u
}

set_hostname() {
    local hostname="$1"; shift

    echo "$hostname" > /etc/hostname
}

set_timezone() {
    local timezone="$1"; shift

    ln -sfT "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
}

set_locale() {
    echo 'LANG="en_US.UTF-8"' >> /etc/locale.conf
    echo 'LC_COLLATE="C"' >> /etc/locale.conf
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
}

set_keymap() {
    echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
}

set_hosts() {
    local hostname="$1"; shift

    cat > /etc/hosts <<EOF
127.0.0.1 localhost.localdomain localhost $hostname
::1       localhost.localdomain localhost $hostname
EOF
}

#set_modules_load() {
#    echo 'microcode' > /etc/modules-load.d/intel-ucode.conf
#}

set_daemons() {
    systemctl enable cronie.service cpupower.service ntpd.service NetworkManager.service
}

set_grub() {
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
}

set_sudoers() {
    sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
}

set_root_password() {
    local password="$1"; shift

    echo -en "$password\n$password" | passwd
}

create_user() {
    local name="$1"; shift
    local password="$1"; shift

    useradd -m -G adm,systemd-journal,wheel,rfkill,games,network,video,audio,optical,floppy,storage,scanner,power,adbusers,wireshark "$name"
    echo -en "$password\n$password" | passwd "$name"
}

update_locate() {
    updatedb
}

set -ex

if [ "$1" == "chroot" ]
then
    configure
else
    setup
fi
