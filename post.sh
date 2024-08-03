#!/bin/bash

## Firewall section
sudo ufw limit 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable

## Flatpak section
flatpak install flathub org.onlyoffice.desktopeditors io.gitlab.librewolf-community com.spotify.Client org.kde.dolphin com.github.tchx84.Flatseal

sudo ln -s /var/lib/flatpak/exports/bin/org.onlyoffice.desktopeditors /usr/bin/onlyoffice
sudo ln -s /var/lib/flatpak/exports/bin/io.gitlab.librewolf-community /usr/bin/librewolf
sudo ln -s /var/lib/flatpak/exports/bin/com.spotify.Client /usr/bin/spotify
sudo ln -s /var/lib/flatpak/exports/bin/org.kde.dolphin /usr/bin/dolphin
sudo ln -s /var/lib/flatpak/exports/bin/com.github.tchx84.Flatseal /usr/bin/flatseal
