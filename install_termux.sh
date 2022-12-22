#!/bin/bash
# Setup script for termux on Android

setup()
{
    # Update
    pkg update
    
    # Upgrade
    pkg upgrade

    # Install Required Packages
    pkg install rclone

    # Press on 'Allow' to read Termux your storage
    termux-setup-storage 

    # Go to Internal Storage
    cd /storage/emulated/0/Documents

    # Create a Directory for Obsidian
    mkdir Obsidian
}
