#!/bin/bash
# Sample script from: https://github.com/starfreck/obsidian-android-sync/blob/main/install.sh
# May be usefull to setup the android program on Termux

setup()
{
    # Update
    pkg update
    
    # Upgrade
    pkg upgrade

    # Install Required Packages
    pkg install python3 rclone

    # Press on 'Allow' to read Termux your storage
    termux-setup-storage 

    # Go to Internal Storage
    cd /storage/emulated/0/Documents

    # Create a Directory for Obsidian
    mkdir Obsidian

    # Git Clone 
    # Install syncrclone    
    python3 -m pip install git+https://github.com/Jwink3101/syncrclone

    # Create syncrclone
    syncrclone --new config.py

    # Move back to home
    cd ~
    # Move sync.sh to ~/.shortcuts
    mv ./sync.sh ~/.shortcuts
}
