#!/bin/sh

set -eu

VERSION="1.0"

die() {
    echo "error: $*"
    exit 1
}

yesno() {
    printf "%s [y/N] " "$1"
    read ans
    case "$ans" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

[ -r /etc/os-release ] || die "can't detect distro"
. /etc/os-release

case " $ID $ID_LIKE " in
    *" debian "*|*" ubuntu "*)
        echo "Debian/Ubuntu based systems aren't supported."
        exit 1
        ;;
    *" fedora "*)
        family=fedora
        ;;
    *" arch "*)
        family=arch
        ;;
    *)
        die "unsupported distro: $PRETTY_NAME"
        ;;
esac

clear

cat <<EOF
SysCraft $VERSION
Linux setup script

Detected: $PRETTY_NAME

Fedora and Arch based systems are supported.
Some applications are installed through Flatpak.
You can skip anything you don't want.

EOF

yesno "Continue?" || exit 0

# Fedora Atomic / rpm-ostree
immutable=0

if [ "$family" = fedora ] &&
   command -v rpm-ostree >/dev/null 2>&1 &&
   ! command -v dnf >/dev/null 2>&1; then
    immutable=1
fi

# Flatpak
if ! command -v flatpak >/dev/null 2>&1; then
    if yesno "Install Flatpak?"; then
        if [ "$family" = fedora ] && [ "$immutable" = 0 ]; then
            sudo dnf install -y flatpak
        elif [ "$family" = arch ]; then
            sudo pacman -S --needed flatpak
        fi
    fi
fi

if command -v flatpak >/dev/null 2>&1; then
    flatpak remote-add --if-not-exists \
        flathub https://dl.flathub.org/repo/flathub.flatpakrepo
fi

# Repositories
if [ "$family" = fedora ] && [ "$immutable" = 0 ]; then
    if yesno "Enable RPM Fusion?"; then
        sudo dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
    fi

    if yesno "Enable Terra?"; then
        sudo dnf copr enable -y terra/terra
    fi

elif [ "$family" = arch ]; then

    if [ "$ID" = cachyos ]; then
        if yesno "Install/update CachyOS repos?"; then
            tmp=$(mktemp -d)
            trap 'rm -rf "$tmp"' EXIT

            cd "$tmp"
            curl -fL \
                https://mirror.cachyos.org/cachyos-repo.tar.xz \
                -o cachyos-repo.tar.xz

            tar -xf cachyos-repo.tar.xz
            cd cachyos-repo
            sudo ./cachyos-repo.sh
            cd /
        fi
    fi

    if yesno "Enable Chaotic AUR?"; then
        sudo pacman-key \
            --recv-key 3056513887B78AEB \
            --keyserver keyserver.ubuntu.com

        sudo pacman-key \
            --lsign-key 3056513887B78AEB

        sudo pacman -U --noconfirm \
            https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst

        sudo pacman -U --noconfirm \
            https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst

        if ! grep -q '^\[chaotic-aur\]' /etc/pacman.conf; then
            printf '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n' |
                sudo tee -a /etc/pacman.conf >/dev/null
        fi
    fi
fi

# Browser
echo
echo "Browser:"
echo "  1) Firefox"
echo "  2) LibreWolf"
echo "  3) Zen"
echo "  4) Chromium"
echo "  5) None"

printf "> "
read browser

case "$browser" in
    1) browser=firefox ;;
    2) browser=librewolf ;;
    3) browser=zen ;;
    4) browser=chromium ;;
    *) browser= ;;
esac

# Discord
echo
echo "Discord:"
echo "  1) Discord"
echo "  2) Vesktop"
echo "  3) Equibop"
echo "  4) None"

printf "> "
read discord

case "$discord" in
    1) discord=discord ;;
    2) discord=vesktop ;;
    3) discord=equibop ;;
    *) discord= ;;
esac

# Gaming
echo
echo "Gaming"

steam=0
lutris=0
wine=0
gamescope=0
mangohud=0
protonge=0
heroic=0
bottles=0
obs=0
goverlay=0
gamemode=0

yesno "Steam?" && steam=1
yesno "Lutris?" && lutris=1
yesno "Wine + Winetricks?" && wine=1
yesno "Gamescope?" && gamescope=1
yesno "MangoHud?" && mangohud=1
yesno "ProtonUp-Qt?" && protonge=1
yesno "Heroic?" && heroic=1
yesno "Bottles?" && bottles=1
yesno "OBS Studio?" && obs=1
yesno "GOverlay?" && goverlay=1
yesno "GameMode?" && gamemode=1

# Other stuff
echo
echo "Other"

teamspeak=0
vlc=0
flatseal=0
prism=0
localsend=0
gearlever=0
fastfetch=0
btop=0
git=0
utils=0

yesno "TeamSpeak?" && teamspeak=1
yesno "VLC?" && vlc=1
yesno "Flatseal?" && flatseal=1
yesno "Prism Launcher?" && prism=1
yesno "LocalSend?" && localsend=1
yesno "Gear Lever?" && gearlever=1

echo
echo "CLI tools"

yesno "Fastfetch?" && fastfetch=1
yesno "btop?" && btop=1
yesno "Git?" && git=1
yesno "curl/wget/archive tools?" && utils=1

packages=""

add() {
    packages="$packages $1"
}

# Native packages
case "$family" in
    fedora)
        [ "$browser" = firefox ] && add firefox
        [ "$browser" = chromium ] && add chromium

        [ "$discord" = discord ] && add discord

        [ "$steam" = 1 ] && add steam
        [ "$lutris" = 1 ] && add lutris
        [ "$wine" = 1 ] && add wine && add winetricks
        [ "$gamescope" = 1 ] && add gamescope
        [ "$mangohud" = 1 ] && add mangohud
        [ "$gamemode" = 1 ] && add gamemode
        [ "$obs" = 1 ] && add obs-studio

        [ "$fastfetch" = 1 ] && add fastfetch
        [ "$btop" = 1 ] && add btop
        [ "$git" = 1 ] && add git

        if [ "$utils" = 1 ]; then
            add curl
            add wget
            add p7zip
            add p7zip-plugins
        fi
        ;;

    arch)
        [ "$browser" = firefox ] && add firefox
        [ "$browser" = librewolf ] && add librewolf
        [ "$browser" = chromium ] && add chromium
        [ "$browser" = zen ] && add zen-browser

        [ "$discord" = discord ] && add discord
        [ "$discord" = vesktop ] && add vesktop
        [ "$discord" = equibop ] && add equibop

        [ "$steam" = 1 ] && add steam
        [ "$lutris" = 1 ] && add lutris
        [ "$wine" = 1 ] && add wine && add winetricks
        [ "$gamescope" = 1 ] && add gamescope
        [ "$mangohud" = 1 ] && add mangohud
        [ "$gamemode" = 1 ] && add gamemode
        [ "$obs" = 1 ] && add obs-studio

        [ "$fastfetch" = 1 ] && add fastfetch
        [ "$btop" = 1 ] && add btop
        [ "$git" = 1 ] && add git

        if [ "$utils" = 1 ]; then
            add curl
            add wget
            add 7zip
        fi
        ;;
esac

if [ -n "$packages" ]; then
    echo
    echo "Installing packages..."

    if [ "$family" = fedora ]; then
        if [ "$immutable" = 0 ]; then
            sudo dnf install -y $packages
        fi
    else
        # Steam needs multilib on normal Arch installs.
        if [ "$steam" = 1 ] &&
           ! grep -Eq '^[[:space:]]*\[multilib\]' /etc/pacman.conf; then

            sudo sed -i \
                '/^[[:space:]]*#\[multilib\]/,/^[[:space:]]*#Include = \/etc\/pacman.d\/mirrorlist/ s/^[[:space:]]*#//' \
                /etc/pacman.conf
        fi

        sudo pacman -Syu --needed $packages
    fi
fi

flatpak_install() {
    flatpak install -y flathub "$1"
}

# Flatpak apps
if command -v flatpak >/dev/null 2>&1; then

    case "$browser" in
        librewolf)
            flatpak_install io.gitlab.librewolf-community
            ;;
        zen)
            flatpak_install app.zen_browser.zen
            ;;
    esac

    case "$discord" in
        vesktop)
            flatpak_install dev.vencord.Vesktop
            ;;
        equibop)
            flatpak_install org.equicord.equibop
            ;;
    esac

    [ "$protonge" = 1 ] &&
        flatpak_install net.davidotek.pupgui2

    [ "$heroic" = 1 ] &&
        flatpak_install com.heroicgameslauncher.hgl

    [ "$bottles" = 1 ] &&
        flatpak_install com.usebottles.bottles

    [ "$goverlay" = 1 ] &&
        flatpak_install io.github.benjamimgois.goverlay

    [ "$teamspeak" = 1 ] &&
        flatpak_install com.teamspeak.TeamSpeak

    [ "$vlc" = 1 ] &&
        flatpak_install org.videolan.VLC

    [ "$flatseal" = 1 ] &&
        flatpak_install com.github.tchx84.Flatseal

    [ "$prism" = 1 ] &&
        flatpak_install org.prismlauncher.PrismLauncher

    [ "$localsend" = 1 ] &&
        flatpak_install org.localsend.localsend_app

    [ "$gearlever" = 1 ] &&
        flatpak_install it.mijorus.gearlever

    # Atomic Fedora doesn't have normal dnf installs.
    if [ "$immutable" = 1 ]; then
        [ "$obs" = 1 ] &&
            flatpak_install com.obsproject.Studio
    fi
fi

# Final update
echo

if [ "$family" = fedora ] && [ "$immutable" = 0 ]; then
    sudo dnf upgrade --refresh -y
elif [ "$family" = arch ]; then
    sudo pacman -Syu
fi

echo
echo "SysCraft $VERSION"
echo "Done."

if [ "$gamemode" = 1 ]; then
    echo
    echo "GameMode:"
    echo "  gamemoderun %command%"
fi

echo
echo "A reboot is recommended if you installed gaming software."
