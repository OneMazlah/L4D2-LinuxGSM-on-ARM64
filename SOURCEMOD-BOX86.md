# SourceMod + MetaMod on box86

This file records the working formula used on `2026-03-16` to get a custom
`MetaMod:Source + SourceMod` core running on an ARM64 host through `box86`.

It exists so the procedure is not lost if chat history is gone later.

## Working State

- Live server target: `Left 4 Dead 2` on ARM64 using `box86`
- MetaMod: custom `1.12-dev` build with plugin API `17`
- SourceMod core: custom `1.12.0.1`
- Verified from live server console:
  - `sm version` works
  - `sdktools.ext` loads
  - `sm_admin` is registered
  - `adminmenu.smx` is running
  - `admin-flatfile.smx` is running
  - `playercommands.smx` is running as `1.12.0-manual`
  - all `24` stock plugins compiled from `1.12` source load
  - `sm_slay` replies with usage and resolves targets

Important `L4D2` coop note:

- the stock SourceMod map-rotation plugins are not campaign-aware enough for this
  server layout
- `mapchooser.smx`, `nextmap.smx`, `nominations.smx`, `randomcycle.smx`, and
  `rockthevote.smx` can override chapter progression and jump to an unrelated map
- keep those plugins disabled unless you replace them with `L4D2`-specific map
  rotation logic

## Why Official Builds Failed

Official SourceMod binaries did not load cleanly on this ARM64 + box86 host because
multiple runtime assumptions broke at once:

- missing glibc C23 symbols such as `__isoc23_strtoul`
- missing fortified wide-char helpers such as `__mbsrtowcs_chk`
- missing `pthread_cond_clockwait`
- SourceMod assumed a `dlopen()` handle could be cast directly to `struct link_map *`
  on Linux, which crashed under `box86`
- newer SourceMod required a newer MetaMod plugin API than the old MetaMod build
- default plugin packaging is awkward on ARM because the x86 `spcomp` binary cannot
  be used in the normal way during packaging

## Repo Files That Matter

- [srcds-arm.sh](srcds-arm.sh)
  - exports the extra library paths needed by `box86`
  - preloads `libisoc23compat.so` and `libtier0compat.so` when present
- [build-box86-shims.sh](build-box86-shims.sh)
  - rebuilds the two compatibility shims with the known-good flags
- [build-sm-default-plugins.sh](build-sm-default-plugins.sh)
  - rebuilds the stock SourceMod plugin set with a native ARM64 `spcomp`
- [make-sourcemod-release-archive.sh](make-sourcemod-release-archive.sh)
  - packages public-ready release assets as `tar.gz`, optional `.zip`, and checksums
- [isoc23-compat.c](isoc23-compat.c)
  - provides the glibc compatibility shim symbols expected by newer x86 binaries
- [tier0-compat.cpp](tier0-compat.cpp)
  - provides the `tier0`/debug helper symbols that `sdktools.ext` needs under `box86`
- [isoc23-compat.map](isoc23-compat.map)
  - assigns the required GLIBC symbol versions
- [patches/mmsource-1.12-box86.patch](patches/mmsource-1.12-box86.patch)
  - MetaMod build patch
- [patches/sourcemod-1.12-box86.patch](patches/sourcemod-1.12-box86.patch)
  - SourceMod build patch

## Repeatable Formula

Use this whenever SourceMod `1.12` gets a new upstream update and you want to rebuild
the custom ARM64 + box86-compatible version.

### 1. Build the Compatibility Shim

Use the helper script:

```bash
/path/to/l4d2-arm/build-box86-shims.sh /tmp/l4d2-arm-box86-shims
```

This produces:

- `/tmp/l4d2-arm-box86-shims/libisoc23compat.so`
- `/tmp/l4d2-arm-box86-shims/libtier0compat.so`

Important:

- keep `libisoc23compat.so` versioned with [isoc23-compat.map](isoc23-compat.map)
- keep `libtier0compat.so` unversioned
- a version-script build of `libtier0compat.so` looked correct in `objdump`, but
  `box86` still failed to resolve the `sdktools.ext` symbols until the exports were
  left unversioned

### 2. Build MetaMod

Use a fresh MetaMod `1.12-dev` checkout, then apply the local patch:

```bash
git clone --branch 1.12-dev https://github.com/alliedmodders/metamod-source.git mmsource-1.12
git -C mmsource-1.12 apply /path/to/l4d2-arm/patches/mmsource-1.12-box86.patch
mkdir build-mm
cd build-mm
CC=i686-linux-gnu-gcc CXX=i686-linux-gnu-g++ \
  python3 ../mmsource-1.12/configure.py \
  --enable-optimize \
  --sdks=l4d2 \
  --targets=x86 \
  --hl2sdk-root /path/to/workdir
ambuild
```

### 3. Build SourceMod

Use a fresh SourceMod `1.12-dev` checkout, then apply the local patch:

```bash
git clone --branch 1.12-dev https://github.com/alliedmodders/sourcemod.git sourcemod-1.12
git -C sourcemod-1.12 apply /path/to/l4d2-arm/patches/sourcemod-1.12-box86.patch
mkdir build-sm
cd build-sm
CC=i686-linux-gnu-gcc CXX=i686-linux-gnu-g++ \
  python3 ../sourcemod-1.12/configure.py \
  --enable-optimize \
  --no-mysql \
  --sdks=l4d2 \
  --targets=x86 \
  --hl2sdk-root /path/to/workdir \
  --mms-path /path/to/mmsource-1.12
ambuild
```

Notes:

- the SourceMod patch disables the stock `plugins/AMBuilder` packaging step
- if upstream changes heavily, refresh the patch instead of forcing it

### 4. Build the Latest Default Plugins

Build the stock `.smx` files separately with a native ARM64 `spcomp`:

```bash
/path/to/l4d2-arm/build-sm-default-plugins.sh \
  /path/to/sourcemod-1.12 \
  /path/to/native-spcomp \
  /tmp/sm112-plugins
```

On the live server used for this test, the working native compiler was:

```text
/home/ubuntu/.tmp-spcomp-native/spcomp/linux-arm64/spcomp
```

That produced the full default plugin set, including:

- `adminmenu.smx`
- `playercommands.smx`
- `funcommands.smx`
- `funvotes.smx`
- `basecomm.smx`
- `mapchooser.smx`

If you need to rebuild the ARM64 `spcomp` itself, keep these notes in mind:

- SourceMod `1.12` source expected an `AMTL` tree under `sourcepawn/third_party/amtl`
- copying `mmsource-1.12/third_party/amtl` into that location was sufficient to start
  the build
- `sourcepawn/third_party/amtl/amtl/am-bits.h` then needed compatibility helpers for:
  - `HashCombine`
  - `SetPointerBits`
  - `GetPointerBits`
  - `ClearPointerBits`
- `sourcepawn/AMBuildScript` also needed warning relaxations and a reduced target list
  so the native build only emitted `spcomp`
- once a working ARM64 `spcomp` exists, keep it around and reuse it for future `1.12`
  plugin rebuilds

### 5. Patch the Built ELF Files

The built x86 binaries need an explicit `DT_NEEDED` entry for the shim library.
`BOX86_LD_PRELOAD` alone was not sufficient.

Run `patchelf --add-needed libisoc23compat.so` on at least:

- `sourcemod.2.l4d2.so`
- `sourcemod.logic.so`
- `sourcepawn.jit.x86.so`
- `sourcemod_mm_i486.so`
- MetaMod `server.so`
- MetaMod `metamod.2.l4d2.so`
- `sdktools.ext.2.l4d2.so`

Run `patchelf --add-needed libtier0compat.so` on:

- `sdktools.ext.2.l4d2.so`

Example:

```bash
patchelf --add-needed libisoc23compat.so sourcemod.2.l4d2.so
patchelf --add-needed libisoc23compat.so sourcemod.logic.so
patchelf --add-needed libisoc23compat.so sourcepawn.jit.x86.so
patchelf --add-needed libisoc23compat.so sourcemod_mm_i486.so
patchelf --add-needed libisoc23compat.so sdktools.ext.2.l4d2.so
patchelf --add-needed libtier0compat.so sdktools.ext.2.l4d2.so
```

Verify:

```bash
patchelf --print-needed sourcemod.logic.so
patchelf --print-needed sdktools.ext.2.l4d2.so
```

### 6. Deploy

Deploy the following to the live LinuxGSM server:

- `libisoc23compat.so` to `/home/steam/serverfiles/bin/`
- `libtier0compat.so` to `/home/steam/serverfiles/bin/`
- the updated [srcds-arm.sh](srcds-arm.sh) to `/home/steam/bin/srcds-arm.sh`
- built SourceMod `.so` files to `left4dead2/addons/sourcemod/bin/`
- built SourceMod extensions to `left4dead2/addons/sourcemod/extensions/`
- rebuilt stock `.smx` files to `left4dead2/addons/sourcemod/plugins/`
- built MetaMod `server.so` and `metamod.2.l4d2.so` to `left4dead2/addons/metamod/bin/`
- `sourcemod.vdf` to `left4dead2/addons/metamod/`

Restart the server after deployment.

Recommended safety step before replacing plugins:

- back up `left4dead2/addons/sourcemod/plugins/` first

### 7. Verify

After restart, verify in this order:

```text
meta version
meta list
sm version
sm plugins info adminmenu.smx
sm plugins info playercommands.smx
sm exts list
sm_admin
sm_slay
```

Expected good signs:

- `meta version` responds
- `sm version` responds
- `sm_admin` replies with `This command can only be used in-game.`
- `sm_slay` replies with usage or a target message instead of `Unknown command`
- `sm exts list` shows `SDK Tools (1.12.0.1)`
- `sm plugins list` shows `24` stock plugins at `1.12.0-manual`

### 8. Package a Release Archive

For a public GitHub Release, prefer packaging from a clean staging tree that
contains only the files you intend to publish.

Example from a curated staging directory:

```bash
/path/to/l4d2-arm/make-sourcemod-release-archive.sh \
  --version 1.12.0.1 \
  --from-staging /tmp/sm112-release-tree
```

Quick private packaging from a verified live server is also supported:

```bash
/path/to/l4d2-arm/make-sourcemod-release-archive.sh \
  --version 1.12.0.1 \
  --from-serverfiles /home/steam/serverfiles
```

That mode intentionally scrubs the most common sensitive files before the
archive is created:

- `addons/sourcemod/configs/admins.cfg`
- `addons/sourcemod/configs/admins_simple.ini`
- `addons/sourcemod/configs/databases.cfg`
- `addons/sourcemod/data/`
- `addons/sourcemod/logs/`
- `addons/sourcemod/plugins.backup-*`

Outputs:

- `dist/sourcemod-box86-l4d2-<version>.tar.gz`
- `dist/sourcemod-box86-l4d2-<version>.zip` when `zip` is installed
- `dist/checksums.txt`

## Admin Authentication Note

For this server, add all equivalent SteamID formats for the same account in
`admins_simple.ini`, then reload admins:

```text
"STEAM_0:0:145689921"    "99:z"
"STEAM_1:0:145689921"    "99:z"
"[U:1:291379842]"        "99:z"
```

Then run:

```text
sm_reloadadmins
```

This avoids confusion when the engine or SourceMod reports the same account in a
different SteamID format.

Important caveat from the live server:

- the current `basecommands.smx` implementation of `sm_reloadadmins` only rebuilds
  `Groups` and `Overrides`
- it does not rebuild `Admins`
- after editing `admins_simple.ini`, reconnect the player or restart/reload the
  relevant SourceMod pieces so the new admin identity is actually re-bound
