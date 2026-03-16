# L4D2 LinuxGSM on ARM64

This package provides a single-script installer for running `SteamCMD + LinuxGSM + box86/box64` for a `Left 4 Dead 2 dedicated server` on `ARM64` Linux hosts.

Tested target class:

- Oracle Cloud Ampere
- Raspberry Pi 4/5 with 64-bit Linux
- other ARM64 Linux systems that can run `box86`/`box64`

Android/Linux environments may work as an experiment, but they are not a primary target and usually have more stability and networking constraints.

## Install

```bash
chmod +x install-l4d2-arm.sh
./install-l4d2-arm.sh
```

The installer will:

- add the `armhf` architecture and install required dependencies
- install `box86` and `box64`
- create a Linux user named `steam`
- download `SteamCMD`
- download `LinuxGSM v25.2.0`
- install the ARM64 wrappers and LinuxGSM patches
- optionally run Steam login and install/update `L4D2`

## Steam Login

Steam credentials are not stored in the repo. These helpers prompt interactively:

```bash
sudo -iu steam
~/bin/steamcmd-login-test.sh
~/bin/l4d2-steamcmd-install.sh
```

If Steam Guard is enabled, `SteamCMD` will ask for your email code during login.

## Server Usage

```bash
sudo -iu steam
cd /home/steam
./l4d2server start
./l4d2server stop
./l4d2server details
./l4d2server monitor
```

## Important Notes

- Do not use the stock `./l4d2server install` or `./l4d2server update` flow on this ARM64 setup.
- Use `~/bin/l4d2-steamcmd-install.sh` for game file installs and updates.
- This is still `x86` emulation on `ARM64`, so performance can be lower than on a native `x86_64` host.
- Open `UDP 27015`, `TCP 27015`, and `UDP 27005` in your firewall or cloud security rules.
- In some clients, `connect IP` can be more reliable than `connect IP:PORT`.

## SourceMod On box86

This repo now includes the compatibility pieces used to get a custom `MetaMod + SourceMod`
core running on `box86`:

- `srcds-arm.sh`
- `isoc23-compat.c`
- `isoc23-compat.map`
- `patches/mmsource-1.12-box86.patch`
- `patches/sourcemod-1.12-box86.patch`
- `SOURCEMOD-BOX86.md`

Read `SOURCEMOD-BOX86.md` before attempting a future SourceMod upgrade on ARM64.

## Credits

This repository builds on upstream tools and projects:

- LinuxGSM, for the server management framework and base modules used here
- Valve, for SteamCMD and Left 4 Dead 2 dedicated server files
- box86 and box64, for x86 and x86_64 compatibility on ARM64 hosts
- Ryan Fortner's Debian repositories for box86 and box64 packages used by the installer

This repository mainly provides ARM64 install automation, wrappers, and compatibility patches around those upstream projects.

Some files in `linuxgsm-modules/` are adapted from LinuxGSM and retain upstream attribution headers.

## Licensing and Attribution Notes

- This repository includes original ARM64 wrapper and installer code, plus adapted upstream integration files.
- Upstream projects keep their own licenses, copyright notices, and trademarks.
- SteamCMD and Left 4 Dead 2 server files are downloaded from Valve during installation and are not relicensed by this repository.
- Files under `linuxgsm-modules/` that were adapted from LinuxGSM should keep their upstream attribution headers.
- If you plan to publish or redistribute this repository, add a top-level `LICENSE` file for the original code in this repo.
