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
HOSTNAME='arch'

# Root password (leave blank to be prompted).
ROOT_PASSWORD=''

# Main user to create (by default, added to wheel group, and others).
USER_NAME='user'

# The main user's password (leave blank to be prompted).
USER_PASSWORD=''

# System timezone.
TIMEZONE='Europe/Warsaw'

# Keymap
KEYMAP='pl'

#----------------------------------------------------------
# This script is responsible for setup before chrooting
#----------------------------------------------------------

setup() {
    timedatectl set-ntp true
    
    if [[ "${DRIVE}" =~ "nvme" ]]; then
        boot="$DRIVE"p1
        swap="$DRIVE"p2
        root="$DRIVE"p3
	
    else
        boot="$DRIVE"1
        swap="$DRIVE"2
        root="$DRIVE"3
    fi
    
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

    # 1000 MB /boot partition, 8000MB swap and rest for the system
    parted -s "$dev" \
        mklabel gpt \
        mkpart boot fat32 1 1000M \
        mkpart swap linux-swap 1000M 4000M \
	mkpart arch ext4 4000M 100% \
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

    #echo 'Updating pkgfile database'
    #update_pkgfile

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
}

config_and_fixes() {
    hwclock --systohc
    
    # Fix long shutdowns
    sed -i 's/#DefaultTimeoutStopSec.*/DefaultTimeoutStopSec=5s/' /etc/systemd/system.conf

    # Enable Colors, Parallel Downloads and multilib in pacman
    sed -i 's/#Color/Color/' /etc/pacman.conf
    sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf

    #Enable multilib
    sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

    # Set make flags to use more cores
    nc=$(grep -c ^processor /proc/cpuinfo)
    sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$nc\"/g" /etc/makepkg.conf
    sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T $nc -z -)/g" /etc/makepkg.conf

    # Initilize and populate Keyring
    pacman-key --init
    pacman-key --populate archlinux
}

install_packages() {
    local packages=''

    # General utilities/libraries
    packages+=' ntp brightnessctl openssh git fontconfig'

    # Audio
    packages+=' pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber'

    # Files systems acces
    packages+=' cifs-utils dosfstools exfat-utils ntfs-3g ntfsprogs mtools'

    # Archive tools
    packages+=' atool p7zip unrar unzip zip'

    # Misc programs
    packages+=' mpv nsxiv thunar dunst picom htop spotify-launcher newsboat zathura zathura-djvu zathura-pdf-mupdf tesseract-data-pol'

    # Gaming
    packages+=' mangohud lib32-mangohud gamemode lib32-gamemode gamescope steam'

    # Xserver
    packages+=' xorg-apps xorg-server xorg-xinit xwallpaper'

    # Fonts
    packages+=' noto-fonts noto-fonts-emoji ttf-dejavu terminus-font libertinus-font'

    # DWM dependencies
    packages+=' freetype2 libx11 libxft'

    # CPU ucode
    packages+=' intel-ucode'
        
    # GPU drivers Intel
    packages+=' mesa lib32-mesa vulkan-intel lib32-vulkan-intel intel-media-driver'
        
    # GPU drivers NVIDIA
    packages+=' mesa lib32-mesa nvidia-utils lib32-nvidia-utils nvidia-dkms'
    
    # GPU drivers Radeon
    #packages+=' mesa lib32-mesa mesa-vdpau lib32-mesa-vdpau vulkan-radeon lib32-vulkan-radeon libva-mesa-driver lib32-libva-mesa-driver vulkan-icd-loader lib32-vulkan-icd-loader'

    # Lutris and Wine
    packages+=' lutris wine-staging giflib lib32-giflib libpng lib32-libpng libldap lib32-libldap gnutls lib32-gnutls mpg123 lib32-mpg123 openal lib32-openal v4l-utils lib32-v4l-utils libpulse lib32-libpulse libgpg-error lib32-libgpg-error alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib libjpeg-turbo lib32-libjpeg-turbo sqlite lib32-sqlite libxcomposite lib32-libxcomposite libxinerama lib32-libgcrypt libgcrypt lib32-libxinerama ncurses lib32-ncurses ocl-icd lib32-ocl-icd libxslt lib32-libxslt libva lib32-libva gtk3 lib32-gtk3 gst-plugins-base-libs lib32-gst-plugins-base-libs'

    pacman -Sy --needed $packages
}

clean_packages() {
    yes | pacman -Scc
}

#update_pkgfile() {
#    pkgfile -u
#}

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
    sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
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
    systemctl enable ntpd.service NetworkManager.service
}

set_grub() {
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch
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

#---------------------------------------------------------
# This part is chroot ad user just to install AUR
#---------------------------------------------------------

aur() {
    install_yay
    install_aur_packages
}
    
install_yay() {
    cd
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    makepkg -si --noconfirm

    cd ..
    rm -rf yay-bin
}

install_aur_packages() {
    yay -S --needed yay-bin librewolf-bin heroic-games-launcher-bin
}

set -ex

if [ "$1" == "chroot" ]; then
    configure
elif [ "$1" == "aur" ]; then
    aur
else
    setup
fi
