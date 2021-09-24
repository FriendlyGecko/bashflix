#!/usr/bin/env bash

echo -n "
██████╗  █████╗ ███████╗██╗  ██╗███████╗██╗     ██╗██╗  ██╗
██╔══██╗██╔══██╗██╔════╝██║  ██║██╔════╝██║     ██║╚██╗██╔╝
██████╔╝███████║███████╗███████║█████╗  ██║     ██║ ╚███╔╝ 
██╔══██╗██╔══██║╚════██║██╔══██║██╔══╝  ██║     ██║ ██╔██╗ 
██████╔╝██║  ██║███████║██║  ██║██║     ███████╗██║██╔╝ ██╗
╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝╚═╝  ╚═╝                                    
"
echo ""
echo "Welcome to bashflix installation script!"
echo ""
echo "The following software will be installed:"
echo "* pirate-get & we-get - torrent search"
echo "* peerflix & vlc - torrent streaming and playing"
echo "* subliminal - subtitles"
echo ""

case $EUID in
   0) : ;; # we are running script as root so we are okay
   *) echo "Please enter you system password (used on brew, apt, npm, pip, etc)." && /usr/bin/sudo $0 "${@}" ;; # not root, become root for the rest of this session (and ask for the sudo password only once)
esac

formula_install() {
    PACINSTALL=false
    for i in "${@}"; do
        if ! command -v "${i}" > /dev/null 2>&1
        then
            echo -e "Installing ${i}"
            $PACMAN "${i}" && PACINSTALL=true
        fi
    done
    if [ "${PACINSTALL}" == true ]
    then
        return 0
    else
        return 1
    fi
}

library_install() {
    PACINSTALL=false
    for i in "${@}"; do
        if ! $PACSEARCH | grep "^${i}$" > /dev/null 2>&1
        then
            echo "Installing ${i}"
            $PACMAN "${i}" && PACINSTALL=true
        fi
    done
    if [[ "${PACINSTALL}" == true ]]
    then
        return 0
    else
        return 1
    fi
}

if [[ $(uname -s) == "Darwin" ]]
then
    KERNEL="Darwin"
    OS="macos"
elif [[ $(uname -s) == "Linux" ]]
then
    KERNEL="Linux"
    if [[ -f /etc/arch-release ]]
    then
        OS="arch"
    elif [[ -f /etc/debian_version ]]
    then
        OS="debian"
    elif [[ -f /etc/redhat-release ]]
    then
        OS="fedora"
    fi
else
    exit 1
fi

if [[ "$OS" == "macos" ]]; then
    echo "Looking for Homebrew ..."
    #if command -v brew > /dev/null 2>&1 # check if brew is installed
    if ! which brew &>/dev/null; then
        echo "Preparing to install Homebrew ..."
        /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
        brew update
    fi
    PACMAN='brew install'
    PACSEARCH='brew list'
else
    declare -A osInfo;
    osInfo[/etc/redhat-release]='sudo dnf --assumeyes install'
    osInfo[/etc/arch-release]='sudo pacman -S --noconfirm'
    osInfo[/etc/gentoo-release]='sudo emerge'
    osInfo[/etc/SuSE-release]='sudo zypper in'
    osInfo[/etc/debian_version]='sudo apt-get --assume-yes install'

    declare -A osSearch;
    osSearch[/etc/redhat-release]='dnf list installed'
    osSearch[/etc/arch-release]='pacman -Qq'
    osSearch[/etc/gentoo-release]="cd /var/db/pkg/ && ls -d */*| sed 's/\/$//'"
    osSearch[/etc/SuSE-release]='rpm -qa'
    osSearch[/etc/debian_version]='dpkg -l' # previously `apt list --installed`.  Can use `sudo apt-cache search`.

    for f in "${!osInfo[@]}"
    do
        if [[ -f $f ]];then
            PACMAN="${osInfo[$f]}"
        fi
    done

    for s in "${!osSearch[@]}"
    do
        if [[ -f $s ]];then
            PACSEARCH="${osSearch[$s]}"
        fi
    done

    sudo apt update -y
    sudo apt install -y git curl software-properties-common build-essential libssl-dev
fi

#define the formula that the majority of OSs use
#so that we only have to redefine formula minimally, as required
PYTHON3='python3'
PIP3='python3-pip'
NPM='npm'
NODE='nodejs'

case $OS in
    macos)
        PYTHON3='python' # Includes pip3 on macOS
        NODE='node'
        ;;
    arch)
        PYTHON3='python'
        PIP3='python-pip'
        ;;
    debian) ;;
    fedora) ;;
esac

formula_install "${PYTHON3}" "${NODE}" "${NPM}" "${PIP3}"
library_install "${PIP3}"

if [[ "$OS" == "macos" ]]; then
  brew upgrade node
  brew upgrade python3
  brew cask install vlc
else
  sudo apt install -y npm vlc libxslt1-dev libxml2-dev 
fi

pip3 install --upgrade pip
pip3 install --upgrade pirate-get
pip3 install --upgrade subliminal
sudo npm install -g npm@latest 
sudo npm install -g peerflix
sudo pip install git+https://github.com/rachmadaniHaryono/we-get
#sudo npm install webtorrent-cli -g
#brew install webtorrent-cli


cd ~
sudo rm -rf bashflix
git clone https://github.com/0zz4r/bashflix.git
cd bashflix
script_directory="$(pwd)"
chmod +x ${script_directory}/bashflix.sh
sudo ln -fs ${script_directory}/bashflix.sh /usr/local/bin/bashflix
sudo echo >$HOME/.bashflix_history
mkdir $HOME/.local/share/bashflix
mv ./plugins/* $HOME/.local/share/bashflix
cd -
