#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
steam_linux_user="${STEAM_LINUX_USER:-steam}"
steam_home="/home/${steam_linux_user}"
linuxgsm_version="v25.2.0"

log() {
	printf '[*] %s\n' "$*"
}

warn() {
	printf '[!] %s\n' "$*" >&2
}

die() {
	printf '[x] %s\n' "$*" >&2
	exit 1
}

run_steam() {
	sudo -u "${steam_linux_user}" -H bash -lc "$*"
}

install_owned() {
	local mode="$1"
	local source="$2"
	local target="$3"

	sudo install -o "${steam_linux_user}" -g "${steam_linux_user}" -m "${mode}" "${source}" "${target}"
}

install_if_missing() {
	local mode="$1"
	local source="$2"
	local target="$3"

	if sudo test -e "${target}"; then
		log "Keeping existing file: ${target}"
		return
	fi

	install_owned "${mode}" "${source}" "${target}"
}

pick_apt_package() {
	local package=""

	for package in "$@"; do
		if apt-cache show "${package}" > /dev/null 2>&1; then
			printf '%s\n' "${package}"
			return 0
		fi
	done

	return 1
}

prompt_yes_no() {
	local prompt="$1"
	local default="${2:-Y}"
	local reply=""

	if [ ! -t 0 ]; then
		return 1
	fi

	if [ "${default}" = "Y" ]; then
		read -r -p "${prompt} [Y/n] " reply
		reply="${reply:-Y}"
	else
		read -r -p "${prompt} [y/N] " reply
		reply="${reply:-N}"
	fi

	case "${reply}" in
		Y|y|yes|YES)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

if [ "$(uname -m)" != "aarch64" ] && [ "$(uname -m)" != "arm64" ]; then
	die "This installer only supports ARM64 hosts."
fi

command -v sudo > /dev/null 2>&1 || die "sudo is required."
command -v apt-get > /dev/null 2>&1 || die "apt-get is required."
sudo -v

if ! command -v curl > /dev/null 2>&1; then
	log "Installing curl for bootstrap"
	sudo apt-get update
	sudo apt-get install -y curl ca-certificates
fi

log "Adding armhf architecture if needed"
sudo dpkg --add-architecture armhf
sudo apt-get update

libcurl_armhf="$(pick_apt_package "libcurl4:armhf" "libcurl4t64:armhf")" || die "Could not find a compatible libcurl armhf package."
libssl_armhf="$(pick_apt_package "libssl3:armhf" "libssl3t64:armhf")" || die "Could not find a compatible libssl armhf package."

packages=(
	curl
	wget
	ca-certificates
	gnupg
	tar
	xz-utils
	file
	tmux
	bc
	jq
	libc6:armhf
	libstdc++6:armhf
	libgcc-s1:armhf
	zlib1g:armhf
	libbz2-1.0:armhf
	libncurses6:armhf
	libtinfo6:armhf
	"${libssl_armhf}"
	"${libcurl_armhf}"
	libudev1:armhf
	libdbus-1-3:armhf
	libsdl2-2.0-0:armhf
)

if optional_pkg="$(pick_apt_package "bsdmainutils")"; then
	packages+=("${optional_pkg}")
fi

log "Installing ARM64/armhf dependencies"
sudo apt-get install -y "${packages[@]}"

log "Configuring Box86/Box64 repositories"
curl -fsSL https://ryanfortner.github.io/box86-debs/box86.list | sudo tee /etc/apt/sources.list.d/box86.list > /dev/null
curl -fsSL https://ryanfortner.github.io/box64-debs/box64.list | sudo tee /etc/apt/sources.list.d/box64.list > /dev/null

tmp_key="$(mktemp)"
curl -fsSL https://ryanfortner.github.io/box86-debs/KEY.gpg | gpg --dearmor > "${tmp_key}"
sudo install -m 644 "${tmp_key}" /etc/apt/trusted.gpg.d/box86-debs-archive-keyring.gpg
rm -f "${tmp_key}"

tmp_key="$(mktemp)"
curl -fsSL https://ryanfortner.github.io/box64-debs/KEY.gpg | gpg --dearmor > "${tmp_key}"
sudo install -m 644 "${tmp_key}" /etc/apt/trusted.gpg.d/box64-debs-archive-keyring.gpg
rm -f "${tmp_key}"

sudo apt-get update
log "Installing Box86 and Box64"
sudo apt-get install -y box64 box86-generic-arm

if ! id -u "${steam_linux_user}" > /dev/null 2>&1; then
	log "Creating Linux user ${steam_linux_user}"
	sudo useradd -m -s /bin/bash "${steam_linux_user}"
fi

log "Creating working directories"
sudo install -d -o "${steam_linux_user}" -g "${steam_linux_user}" \
	"${steam_home}/steamcmd" \
	"${steam_home}/serverfiles" \
	"${steam_home}/Steam" \
	"${steam_home}/bin" \
	"${steam_home}/.steam/sdk32" \
	"${steam_home}/.steam/sdk64" \
	"${steam_home}/lgsm/config-lgsm/l4d2server" \
	"${steam_home}/serverfiles/left4dead2/cfg"

if ! sudo test -x "${steam_home}/steamcmd/linux32/steamcmd"; then
	log "Downloading SteamCMD"
	run_steam "cd ~/steamcmd && curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar xzf -"
fi

log "Creating steamclient.so symlinks"
run_steam "ln -sf ~/steamcmd/linux32/steamclient.so ~/.steam/sdk32/steamclient.so"
run_steam "if [ -f ~/steamcmd/linux64/steamclient.so ]; then ln -sf ~/steamcmd/linux64/steamclient.so ~/.steam/sdk64/steamclient.so; fi"
run_steam "grep -qxF 'export PATH=\"\$HOME/bin:\$PATH\"' ~/.bashrc || printf '\nexport PATH=\"\$HOME/bin:\$PATH\"\n' >> ~/.bashrc"

log "Installing LinuxGSM ${linuxgsm_version}"
run_steam "cd ~ && curl -fsSL https://raw.githubusercontent.com/GameServerManagers/LinuxGSM/${linuxgsm_version}/linuxgsm.sh -o linuxgsm.sh"
run_steam "cd ~ && chmod +x linuxgsm.sh && ./linuxgsm.sh l4d2server && rm -f linuxgsm.sh"
run_steam "cd ~ && ./l4d2server details >/dev/null 2>&1 || true"

log "Installing ARM64 wrappers and config"
install_owned 755 "${script_dir}/steamcmd-box86" "${steam_home}/bin/steamcmd-box86"
install_owned 755 "${script_dir}/steamcmd" "${steam_home}/bin/steamcmd"
install_owned 755 "${script_dir}/steamcmd-login-test.sh" "${steam_home}/bin/steamcmd-login-test.sh"
install_owned 755 "${script_dir}/l4d2-steamcmd-install.sh" "${steam_home}/bin/l4d2-steamcmd-install.sh"
install_owned 755 "${script_dir}/srcds-arm.sh" "${steam_home}/bin/srcds-arm.sh"
install_owned 644 "${script_dir}/linuxgsm/common.cfg" "${steam_home}/lgsm/config-lgsm/l4d2server/common.cfg"
install_owned 644 "${script_dir}/linuxgsm/l4d2server.cfg" "${steam_home}/lgsm/config-lgsm/l4d2server/l4d2server.cfg"
install_owned 644 "${script_dir}/linuxgsm-modules/check_system_requirements.sh" "${steam_home}/lgsm/modules/check_system_requirements.sh"
install_owned 644 "${script_dir}/linuxgsm-modules/check_deps.sh" "${steam_home}/lgsm/modules/check_deps.sh"
install_if_missing 644 "${script_dir}/game/l4d2server.cfg" "${steam_home}/serverfiles/left4dead2/cfg/l4d2server.cfg"

log "Running basic SteamCMD smoke test"
run_steam "~/bin/steamcmd +quit"

if prompt_yes_no "Run Steam login test now?" "Y"; then
	run_steam "~/bin/steamcmd-login-test.sh"
fi

if prompt_yes_no "Install or update Left 4 Dead 2 now?" "Y"; then
	run_steam "~/bin/l4d2-steamcmd-install.sh"
fi

cat <<EOF

Done.

Main commands:
  sudo -iu ${steam_linux_user}
  cd ${steam_home}
  ./l4d2server start
  ./l4d2server stop
  ./l4d2server details
  ~/bin/l4d2-steamcmd-install.sh

Notes:
  - Do not use ./l4d2server install on this ARM64 setup.
  - Open UDP 27015, TCP 27015, and UDP 27005 in your firewall or security group.
  - Steam username/password are requested interactively and are not stored in this repo.
EOF
