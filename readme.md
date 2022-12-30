# Rclone Autosync

Program to automate the `rclone bisync` command on Ubuntu and Android devices (with Termux).

It also features utilities to sync Obisidian Vault.

## Usage

- 1) Config rclone remote drive:

```bash
rclone config
```

- 2) Run the program with the choosen local_path and remote_path

```bash
autosync <local_path> <remote_path>
```

- 3) Prior runs will use this

## How it works

- Handle `bisync` first run by re-running it with `--resync`
- Handle empty local and cloud folders by creating `rclone_keep` file *

* May be dangerous: if some failure leads to erasing all data from local or remote, it may cause data loss. Google Drive will trash the items, so it may serve as a backup, but run at your own risk.

## Install and Setup on PC

TODO

## Install and Setup on Android

TODO

## Considerations

TODO