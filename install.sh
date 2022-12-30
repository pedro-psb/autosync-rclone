#!/bin/bash

if [[ -e ~/bin/autosync-run ]]; then
    echo 'Autosync is already installed'
else
    echo 'Installing autosync'
    program_path="$PWD/autosync-run.sh"

    mkdir ~/.config/autosync
    ln -s $program_path "$HOME/bin/autosync-run"
fi