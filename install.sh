#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (using sudo)."
  exit 1
fi

echo "=================================================="
echo "    Universal Mac Driver Installer for Linux     "
echo "=================================================="

# ==========================================
# 1. DETECT LINUX DISTRO
# ==========================================
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    DISTRO_LIKE=$ID_LIKE
else
    echo "Error: Cannot detect Linux distribution."
    exit 1
fi

echo "Detected OS: $NAME ($DISTRO)"

# Setup package manager and installer strings dynamically
case "$DISTRO" in
    ubuntu|debian|pop|mint)
        PKG_MAN="apt-get"
        INSTALL_CMD="apt-get install -y"
        REFRESH_CMD="apt-get update"
        ;;
    fedora)
        PKG_MAN="dnf"
        INSTALL_CMD="dnf install -y"
        REFRESH_CMD="dnf upgrade -y --refresh"
        ;;
    arch|manjaro)
        PKG_MAN="pacman"
        INSTALL_CMD="pacman -Sy --noconfirm"
        REFRESH_CMD="pacman -Syu --noconfirm"
        ;;
    opensuse*|suse)
        PKG_MAN="zypper"
        INSTALL_CMD="zypper install -y"
        REFRESH_CMD="zypper refresh"
        ;;
    *)
        # Fallback to ID_LIKE if specific ID matches fail
        if [[ "$DISTRO_LIKE" == *"debian"* || "$DISTRO_LIKE" == *"ubuntu"* ]]; then
            PKG_MAN="apt-get"
            INSTALL_CMD="apt-get install -y"
            REFRESH_CMD="apt-get update"
        elif [[ "$DISTRO_LIKE" == *"arch"* ]]; then
            PKG_MAN="pacman"
            INSTALL_CMD="pacman -Sy --noconfirm"
            REFRESH_CMD="pacman -Syu --noconfirm"
        else
            echo "Unsupported Linux distribution family: $DISTRO"
            exit 1
        fi
        ;;
esac

# ==========================================
# 2. DETECT MAC MODEL & HARDWARE
# ==========================================
MAC_MODEL=$(dmidecode -s system-product-name | tr -d '[:space:]')
echo "Detected Mac Hardware: $MAC_MODEL"

# Probe for specific chips rather than hardcoding exact Mac models
HAS_BROADCOM_WIFI=$(lspci | grep -iE 'broadcom|bcm43')
HAS_NVIDIA=$(lspci | grep -i 'nvidia')
HAS_FACETIME_HD=$(lspci -vmm | grep -i 'facetime')

# Alternative check for FaceTime HD camera (USB based on many models)
if [ -z "$HAS_FACETIME_HD" ]; then
    HAS_FACETIME_HD=$(lsusb | grep -i 'facetime')
fi

# ==========================================
# 3. DRIVER INSTALLATION LOGIC
# ==========================================

install_wifi() {
    if [ -z "$HAS_BROADCOM_WIFI" ]; then
        echo "No Broadcom Wi-Fi chip detected. Skipping."
        return
    fi
    
    echo "Installing Broadcom Wi-Fi drivers for $DISTRO..."
    case "$PKG_MAN" in
        apt-get)
            $REFRESH_CMD
            $INSTALL_CMD bcmwl-kernel-source firmware-b43-installer
            ;;
        dnf)
            # Enable RPM Fusion if not present
            if ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
                dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
                               https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
            fi
            $REFRESH_CMD
            $INSTALL_CMD akmod-wl
            ;;
        pacman)
            $REFRESH_CMD
            $INSTALL_CMD broadcom-wl-dkms
            ;;
        zypper)
            $REFRESH_CMD
            $INSTALL_CMD broadcom-wl broadcom-wl-kmp-default
            ;;
    esac
}

install_camera() {
    if [ -z "$HAS_FACETIME_HD" ]; then
        echo "No FaceTime HD Camera detected. Skipping."
        return
    fi

    echo "Installing FaceTime HD webcam dependencies and drivers..."
    
    # Install dependencies based on package manager
    case "$PKG_MAN" in
        apt-get)
            $INSTALL_CMD git dkms build-essential kmod cpio curl xz-utils
            ;;
        dnf)
            $INSTALL_CMD git dkms kernel-devel make curl xz cpio
            ;;
        pacman)
            $INSTALL_CMD git dkms linux-headers make curl xz cpio
            ;;
        zypper)
            $INSTALL_CMD git dkms kernel-default-devel make curl xz cpio
            ;;
    esac

    # Extracting and installing Apple FaceTime HD camera firmware upstream
    cd /tmp || exit
    rm -rf facetimehd-firmware facetimehd
    
    # 1. Firmware Extraction
    git clone https://github.com/patjak/facetimehd-firmware.git
    cd facetimehd-firmware || exit
    make && make install
    cd /tmp || exit

    # 2. Driver compilation & installation via DKMS (Universal method)
    git clone https://github.com/patjak/facetimehd.git
    cd facetimehd || exit
    make
    
    # Manual DKMS registration to avoid breaking on rolling releases
    FW_VER=$(git rev-parse --short HEAD)
    mkdir -p /usr/src/facetimehd-$FW_VER
    cp -r * /usr/src/facetimehd-$FW_VER
    
    cat <<EOF > /usr/src/facetimehd-$FW_VER/dkms.conf
PACKAGE_NAME="facetimehd"
PACKAGE_VERSION="$FW_VER"
BUILT_MODULE_NAME[0]="facetimehd"
DEST_MODULE_LOCATION[0]/kernel/drivers/media/pci/facetimehd"
AUTOINSTALL="yes"
EOF

    dkms add -m facetimehd -v $FW_VER
    dkms build -m facetimehd -v $FW_VER
    dkms install -m facetimehd -v $FW_VER
    
    # Load module
    modprobe facetimehd
    echo "facetimehd" >> /etc/modules-load.d/facetimehd.conf
}

install_nvidia() {
    if [ -z "$HAS_NVIDIA" ]; then
        echo "No Nvidia GPU detected. Skipping."
        return
    fi

    echo "Installing Nvidia graphics drivers..."
    echo "Warning: Older Macs (pre-2014) usually require legacy drivers (e.g., 470xx or 390xx series)."
    
    case "$PKG_MAN" in
        apt-get)
            $INSTALL_CMD nvidia-detect
            # Auto-detect best legacy vs modern driver version on Debian/Ubuntu systems
            BEST_DRIVER=$(nvidia-detect | grep -E 'nvidia-driver-|nvidia-legacy-')
            if [ -n "$BEST_DRIVER" ]; then
                $INSTALL_CMD $BEST_DRIVER
            else
                $INSTALL_CMD nvidia-driver
            fi
            ;;
        dnf)
            # Installs the modern/common driver. User may need 470xx manually depending on exact GPU age.
            $INSTALL_CMD akmod-nvidia
            ;;
        pacman)
            # Arch users usually rely on AUR for legacy cards, trying dynamic DKMS first
            $INSTALL_CMD nvidia-dkms nvidia-utils
            ;;
        zypper)
            # Add Nvidia repository dynamically for openSUSE
            zypper ar -f https://download.nvidia.com/opensuse/tumbleweed NvidiaOS
            $REFRESH_CMD
            $INSTALL_CMD x11-video-nvidiaG06
            ;;
    esac
}

# ==========================================
# 4. INTERACTIVE MENU
# ==========================================
echo ""
echo "Select installation target:"
echo "1) Run Auto-Installer (Detect and install all applicable drivers)"
echo "2) Install Wi-Fi Driver Only"
echo "3) Install FaceTime HD Camera Driver Only"
echo "4) Install Nvidia Graphics Driver Only"
echo "5) Exit"
read -p "Enter your choice [1-5]: " choice

case $choice in
    1)
        install_wifi
        install_camera
        install_nvidia
        ;;
    2) install_wifi ;;
    3) install_camera ;;
    4) install_nvidia ;;
    5) echo "Exiting."; exit 0 ;;
    *) echo "Invalid option. Exiting."; exit 1 ;;
esac

echo ""
echo "=================================================="
echo "Process Complete! Please restart your machine to apply all changes."
echo "=================================================="
