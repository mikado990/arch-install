#!/usr/bin/env bash

source $HOME/arch-install/configs/setup.conf

cd ~
mkdir "/home/$USERNAME/.cache"
mkdir "/home/$USERNAME/.config"
mkdir -p "/home/$USERNAME/.local/state"
mkdir -p "/home/$USERNAME/.local/src"
mkdir -p "/home/$USERNAME/.local/share"
mkdir -p "/home/$USERNAME/.local/state/bash"
mkdir -p "/home/$USERNAME/.local/share/wineprefixes"

cp -r $HOME/arch-install/configs/.config/* /home/$USERNAME/.config/
cp -rf $HOME/arch-install/configs/.bashrc /home/$USERNAME/
cp -rf $HOME/arch-install/configs/.bash_profile /home/$USERNAME/
cp -rf $HOME/arch-install/configs/Pictures /home/$USERNAME/

while IFS= read -r line ; do
    packages+=" ${line}"
done < $HOME/arch-install/pkg-files/pacman-pkgs.txt

while IFS= read -r line ; do
    packages+=" ${line}"
done < $HOME/arch-install/pkg-files/${DESKTOP_ENV}.txt

sudo pacman -S --needed --noconfirm $packages

if [[ ! $AUR_HELPER == none ]]; then
  cd ~
  git clone "https://aur.archlinux.org/$AUR_HELPER.git"
  cd ~/$AUR_HELPER
  makepkg -si --noconfirm
fi

while IFS= read -r line ; do
    aur+=" ${line}"
done < $HOME/arch-install/pkg-files/aur-pkgs.txt

$AUR_HELPER -S --noconfirm $aur

export PATH=$PATH:~/.local/bin

# Download reshade shaders
git clone https://github.com/crosire/reshade-shaders /home/$USERNAME/.local/share/reshade-shaders

# Clone Suckless tools
if [[ $DESKTOP_ENV == dwm ]]; then
    git clone https://git.suckless.org/dwm /home/$USERNAME/.local/src/dwm
    git clone https://git.suckless.org/dmenu /home/$USERNAME/.local/src/dmenu
    git clone https://git.suckless.org/st /home/$USERNAME/.local/src/st
fi

echo -ne "
-------------------------------------------------------------------------
                    SYSTEM READY FOR 3-post-setup.sh
-------------------------------------------------------------------------
"
exit
