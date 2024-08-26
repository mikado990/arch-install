#!/bin/bash

## Firewall section
sudo ufw limit 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable

## Wine dependencies
sudo pacman -S --needed --asdeps giflib lib32-giflib gnutls lib32-gnutls v4l-utils lib32-v4l-utils libpulse lib32-libpulse alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib sqlite lib32-sqlite libxcomposite lib32-libxcomposite ocl-icd lib32-ocl-icd libva lib32-libva gtk3 lib32-gtk3 gst-plugins-base-libs lib32-gst-plugins-base-libs vulkan-icd-loader lib32-vulkan-icd-loader sdl2 lib32-sdl2

## Flatpak section
flatpak install flathub org.onlyoffice.desktopeditors io.gitlab.librewolf-community com.spotify.Client com.discordapp.Discord

#sudo ln -s /var/lib/flatpak/exports/bin/org.onlyoffice.desktopeditors /usr/bin/onlyoffice
#sudo ln -s /var/lib/flatpak/exports/bin/io.gitlab.librewolf-community /usr/bin/librewolf
#sudo ln -s /var/lib/flatpak/exports/bin/com.spotify.Client /usr/bin/spotify
