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
  - `sm_admin` is registered
  - `adminmenu.smx` is running
  - `admin-flatfile.smx` is running
- Known remaining issue:
  - `sdktools.ext.2.l4d2.so` still fails under `box86`
  - some stock plugins that require `SDKTools` do not load yet

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
  - preloads `libisoc23compat.so` when present
- [isoc23-compat.c](isoc23-compat.c)
  - provides the compatibility shim symbols expected by newer x86 binaries
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

Build a 32-bit x86 shared library from the files in this repo:

```bash
i686-linux-gnu-gcc -m32 -shared -fPIC \
  -Wl,--version-script=/path/to/l4d2-arm/isoc23-compat.map \
  -o /tmp/libisoc23compat.so \
  /path/to/l4d2-arm/isoc23-compat.c \
  -pthread
```

After building, confirm the exported symbols:

```bash
objdump -T /tmp/libisoc23compat.so | grep -E 'isoc23|mbsrtowcs|wmemset|pthread_cond_clockwait'
```

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
- keep the already-working stock `.smx` plugin set on the live server unless you also
  solve x86 plugin compilation on the ARM host
- if upstream changes heavily, refresh the patch instead of forcing it

### 4. Patch the Built ELF Files

The built x86 binaries need an explicit `DT_NEEDED` entry for the shim library.
`BOX86_LD_PRELOAD` alone was not sufficient.

Run `patchelf --add-needed libisoc23compat.so` on at least:

- `sourcemod.2.l4d2.so`
- `sourcemod.logic.so`
- `sourcepawn.jit.x86.so`
- `sourcemod_mm_i486.so`
- MetaMod `server.so`
- MetaMod `metamod.2.l4d2.so`

Example:

```bash
patchelf --add-needed libisoc23compat.so sourcemod.2.l4d2.so
patchelf --add-needed libisoc23compat.so sourcemod.logic.so
patchelf --add-needed libisoc23compat.so sourcepawn.jit.x86.so
patchelf --add-needed libisoc23compat.so sourcemod_mm_i486.so
```

Verify:

```bash
patchelf --print-needed sourcemod.logic.so
```

### 5. Deploy

Deploy the following to the live LinuxGSM server:

- `libisoc23compat.so` to `/home/steam/serverfiles/bin/`
- the updated [srcds-arm.sh](srcds-arm.sh) to `/home/steam/bin/srcds-arm.sh`
- built SourceMod `.so` files to `left4dead2/addons/sourcemod/bin/`
- built SourceMod extensions to `left4dead2/addons/sourcemod/extensions/`
- built MetaMod `server.so` and `metamod.2.l4d2.so` to `left4dead2/addons/metamod/bin/`
- `sourcemod.vdf` to `left4dead2/addons/metamod/`

Restart the server after deployment.

### 6. Verify

After restart, verify in this order:

```text
meta version
meta list
sm version
sm plugins info adminmenu.smx
sm exts list
sm_admin
```

Expected good signs:

- `meta version` responds
- `sm version` responds
- `sm_admin` replies with `This command can only be used in-game.`

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
