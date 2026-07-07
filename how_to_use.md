# Universal Mac Linux Driver Installer - User Guide

This guide explains how to use the universal bash script to automatically detect your Mac hardware, identify your Linux distribution, and install the required proprietary drivers (Wi-Fi, FaceTime HD Camera, and Nvidia Graphics).

---

## 📋 Table of Contents
1. [Prerequisites](#prerequisites)
2. [Quick Start (Installation)](#quick-start-installation)
3. [How It Works](#how-it-works)
4. [Post-Installation Steps](#post-installation-steps)
5. [Troubleshooting & Limitations](#troubleshooting--limitations)

---

## 🔍 Prerequisites

Before running the script, ensure your system meets the following requirements:
* **Root Privileges:** You must have `sudo` access.
* **Internet Connection:** An active internet connection is required to fetch dependencies and packages. *Note: If your Mac's Wi-Fi isn't working yet, use an Ethernet adapter, USB tethering from your smartphone, or a Wi-Fi dongle to run the script.*
* **Architecture:** This script is designed for Intel-based Macs (Approx. 2006–2020). 

> ⚠️ **Important Note on Apple Silicon (M1/M2/M3/M4+):** Modern ARM-based Apple Silicon Macs do not use standard Linux driver structures or x86 packages. If you are running Linux on Apple Silicon, please use specialized distributions like Asahi Linux instead of this script.

---

## 🚀 Quick Start (Installation)

Follow these steps to deploy and run the script on your Linux machine:

### Step 1: Save the Script
Copy the script code, create a new file named `install_driver.sh` on your Linux machine, and paste the code into it.

### Step 2: Make it Executable
Open your terminal, navigate to the directory where you saved the file, and grant it execution permissions:
```bash
chmod +x install_driver.sh
