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

## Docker

This repo also includes a `Dockerfile` for `ARM64` hosts. The image prepares:

- `box86` and `box64`
- `SteamCMD`
- `LinuxGSM` bootstrap support
- the ARM64 wrapper/config files from this repo

On first container start, the entrypoint downloads `LinuxGSM` if it is not already
present. Valve game files are not bundled; install those at runtime with your own
Steam account or mounted persistent data.

Build the image:

```bash
docker build -t l4d2-arm .
```

Suggested persistent mounts:

- `/home/steam/serverfiles`
- `/home/steam/lgsm/config-lgsm`
- `/home/steam/log`

Run an interactive bootstrap shell:

```bash
docker run --rm -it \
  --platform linux/arm64 \
  --name l4d2-arm-shell \
  -v l4d2-serverfiles:/home/steam/serverfiles \
  -v l4d2-config:/home/steam/lgsm/config-lgsm \
  -v l4d2-log:/home/steam/log \
  --entrypoint bash \
  l4d2-arm
```

From there, switch to the `steam` user and run the normal helper:

```bash
sudo -iu steam
~/bin/l4d2-steamcmd-install.sh
```

Run the server container after the game files are installed:

```bash
docker run -d \
  --platform linux/arm64 \
  --name l4d2-arm \
  -p 27015:27015/tcp \
  -p 27015:27015/udp \
  -p 27005:27005/udp \
  -v l4d2-serverfiles:/home/steam/serverfiles \
  -v l4d2-config:/home/steam/lgsm/config-lgsm \
  -v l4d2-log:/home/steam/log \
  l4d2-arm
```

For unattended first-time install, the container supports:

```bash
-e AUTO_INSTALL_L4D2=1
-e STEAM_USERNAME=your_steam_username
-e STEAM_PASSWORD=your_steam_password
```

Use that only if you accept Steam credentials being visible in container metadata.

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
core running on `box86`.

### For Normal Users

If you only want a ready-to-use `SourceMod + MetaMod` package for `L4D2` on
`ARM64 + box86`, do not start with the build notes.

Use the prebuilt GitHub Release asset instead:

- `sourcemod-box86-l4d2-<version>.tar.gz`

That release asset is the custom `box86` build. It is not the official upstream
SourceMod archive.

Normal user flow:

1. Download the latest `sourcemod-box86-l4d2-<version>.tar.gz` from GitHub Releases.
2. Extract it into your server root.
3. Replace your wrapper with `srcds-arm.sh` if needed.
4. Edit `addons/sourcemod/configs/admins_simple.ini` and other local configs after deployment.

### For Maintainers

Only read `SOURCEMOD-BOX86.md` if you want to rebuild, update, or package a new
release of the custom `box86` version.

This repo includes these maintainer files:

- `srcds-arm.sh`
- `build-box86-shims.sh`
- `build-sm-default-plugins.sh`
- `make-sourcemod-release-archive.sh`
- `isoc23-compat.c`
- `tier0-compat.cpp`
- `isoc23-compat.map`
- `patches/mmsource-1.12-box86.patch`
- `patches/sourcemod-1.12-box86.patch`
- `SOURCEMOD-BOX86.md`

`SOURCEMOD-BOX86.md` records the working `box86` formula, the shim build, and
how to rebuild the latest default SourceMod plugins with a native ARM64 `spcomp`.

After you have a clean release tree or a verified live serverfiles tree, use
`make-sourcemod-release-archive.sh` to generate GitHub Release assets:

```bash
./make-sourcemod-release-archive.sh \
  --version 1.12.0.1 \
  --from-serverfiles /home/steam/serverfiles
```

That creates `dist/sourcemod-box86-l4d2-<version>.tar.gz`, an optional `.zip`
if `zip` is installed, and `dist/checksums.txt`.

For public releases, prefer a clean staging tree over a live serverfiles tree.
The live packaging mode scrubs the common sensitive configs, but a curated
staging tree is still safer.

For `L4D2` coop/campaign flow, keep these stock SourceMod map-rotation plugins
disabled unless you replace them with `L4D2`-aware logic:

- `mapchooser.smx`
- `nextmap.smx`
- `nominations.smx`
- `randomcycle.smx`
- `rockthevote.smx`

The stock versions can override chapter progression and send players to an
unrelated map at the end of a chapter.

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
