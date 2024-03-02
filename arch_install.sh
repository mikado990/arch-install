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

#----------------------------------------------------------
# This part sets up all the variables 
#----------------------------------------------------------

# Drive to install to.
DRIVE='/dev/sda'

# Hostname of the installed machine.
HOSTNAME='host100'

# Root password (leave blank to be prompted).
ROOT_PASSWORD=''

# Main user to create (by default, added to wheel group, and others).
USER_NAME='user'

# The main user's password (leave blank to be prompted).
USER_PASSWORD=''

# System timezone.
TIMEZONE='Europe/Warsaw'

KEYMAP='pl'
# KEYMAP='dvorak'

# Choose your video driver
# For Intel
VIDEO_DRIVER="intel"
# For AMD
#VIDEO_DRIVER="amd"

#----------------------------------------------------------
# This script is responsible for setup before chrooting
#----------------------------------------------------------

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

    echo 'Chrooting as user: "$USER_NAME" to install AUR helper and packages'
    arch-chroot /mnt /usr/bin/runuser -u $USER_NAME ./setup.sh aur

    echo 'Unmounting everything from /mnt'
    unmount_filesystems
}

partition_drive() {
    local dev="$1"; shift

    # 1000 MB /boot partition, 4000MB swap and rest for the system
    parted -s "$dev" \
        mklabel gpt \
        mkpart boot fat32 1 1000M \
        mkpart swap linux-swap 1000M 5000M \
	mkpart arch ext4 5000M 100% \
        set 1 esp on \
        set 2 swap on
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
    reflector -a 48 --country 'Poland,' -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist

    # Enable Paralel downloads for faster downloads (the same is applied after chroot)
    sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf

    pacstrap -K /mnt base base-devel linux-firmware linux-zen linux-zen-headers networkmanager grub efibootmgr vim man-db man-pages --noconfirm --needed
}

set_fstab() {
    genfstab -U /mnt >> /mnt/etc/fstab
}

unmount_filesystems() {
    local swap="$1"; shift
    
    umount -R /mnt
    swapoff "$swap"
}

#-------------------------------------------------------------------------
# This part is for configurtion inside chroot
#-------------------------------------------------------------------------

configure() {
    echo 'Applying config changes and fixes'
    config_and_fixes

    echo 'Installing additional packages'
    install_packages

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

config_and_fixes() {
    hwclock --systohc
    
    # Fix long shutdowns
    sed -i 's/#DefaultTimeoutStopSec.*/DefaultTimeoutStopSec=5s/' /etc/systemd/system.conf

    # Enable Colors, Parallel Downloads and multilib in pacman
    sed -i 's/#Color/Color/' /etc/pacman.conf
    sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf

    # Initilize and populate Keyring
    pacman-key --init
    pacman-key --populate archlinux
}

install_packages() {
    local packages=''

    # General utilities/libraries
    packages+=' aspell-en cpupower cronie ntp openssh pkgfile powertop rfkill rsync'

    # Audio
    packages+=' pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber'

    # Development packages
    packages+=' gdb git valgrind'

    # Files systems acces
    packages+=' dosfstools exfat-utils ntfs-3g ntfsprogs mtools'

    # Archive tools
    packages+=' atool p7zip unrar unzip zip'

    # Misc programs
    packages+=' vlc'

    # Xserver
    packages+=' xorg-apps xorg-server xorg-xinit'

    # Fonts
    packages+=' noto-fonts noto-fonts-emoji ttf-dejavu libertinus-font'

    # KDE Dektop Environment
    packages+=' sddm plasma ark dolphin dolphin-plugins gwenview kate kmix konsole ktorrent okular partitionmanager plasmatube spectacle'

    # On Intel processors
    packages+=' intel-ucode'

    if [ "$VIDEO_DRIVER" = "intel" ]
    then
        packages+=' mesa vulkan-intel intel-media-driver'
    elif [ "$VIDEO_DRIVER" = "amd" ]
    then
        packages+=' mesa mesa-vdpau  xf86-video-amdgpu vulkan-radeon libva-mesa-driver'
    fi

    pacman -Sy --noconfirm --needed $packages
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
    systemctl enable cronie.service cpupower.service ntpd.service NetworkManager.service sddm.service
}

set_grub() {
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
}

set_sudoers() {
    sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
}

set_root_password() {
    local password="$1"; shift

    echo -en "$password\n$password" | passwd
}

create_user() {
    local name="$1"; shift
    local password="$1"; shift

    useradd -m -G wheel,rfkill,games,video,audio,storage,kvm "$name"
    echo -en "$password\n$password" | passwd "$name"
}

update_locate() {
    updatedb
}

#---------------------------------------------------------
# This part is chroot ad user just to install AUR
#---------------------------------------------------------

aur() {
    install_yay
    install_aur_packages
}
    
install_yay() {
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    makepkg -si --noconfirm

    cd ..
    rm -rf yay-bin
}

install_aur_packages() {
    yay -Sy --noconfirm yay-bin onlyoffice-bin librewolf-bin --aur
}

set -ex

if [ "$1" == "chroot" ]; then
    configure
elif [ "$1" == "aur" ]; then
    aur
else
    setup
fi
