#!/bin/bash

if [[ -e ~/bin/autosync-run ]]; then
    echo 'Autosync is already installed'
else
    echo 'Installing autosync'
    base_path=$(pwd)
    program_path="$base_path/autosync-run.sh"

    mkdir ~/.config/autosync
    ln -s $program_path ~/bin/autosync
fi