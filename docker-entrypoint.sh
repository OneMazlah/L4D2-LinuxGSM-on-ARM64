#!/usr/bin/env bash
set -euo pipefail

repo_dir="/opt/l4d2-arm"
steam_linux_user="${STEAM_LINUX_USER:-steam}"
steam_home="/home/${steam_linux_user}"
linuxgsm_version="${LINUXGSM_VERSION:-v25.2.0}"

log() {
	printf '[docker-entrypoint] %s\n' "$*"
}

die() {
	printf '[docker-entrypoint] %s\n' "$*" >&2
	exit 1
}

run_steam() {
	sudo -u "${steam_linux_user}" -H bash -lc "$*"
}

install_owned() {
	local mode="$1"
	local source="$2"
	local target="$3"

	install -o "${steam_linux_user}" -g "${steam_linux_user}" -m "${mode}" "${source}" "${target}"
}

install_if_missing() {
	local mode="$1"
	local source="$2"
	local target="$3"

	if [ -e "${target}" ]; then
		return
	fi

	install_owned "${mode}" "${source}" "${target}"
}

bootstrap_runtime() {
	install -d -o "${steam_linux_user}" -g "${steam_linux_user}" \
		"${steam_home}/steamcmd" \
		"${steam_home}/serverfiles" \
		"${steam_home}/Steam" \
		"${steam_home}/bin" \
		"${steam_home}/.steam/sdk32" \
		"${steam_home}/.steam/sdk64" \
		"${steam_home}/lgsm/data" \
		"${steam_home}/lgsm/modules" \
		"${steam_home}/lgsm/config-lgsm/l4d2server" \
		"${steam_home}/serverfiles/left4dead2/cfg" \
		"${steam_home}/log"
	chown -R "${steam_linux_user}:${steam_linux_user}" "${steam_home}"

	if [ ! -x "${steam_home}/steamcmd/linux32/steamcmd" ]; then
		log "Downloading SteamCMD into ${steam_home}/steamcmd"
		run_steam "cd ~/steamcmd && curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar xzf -"
	fi

	run_steam "ln -sf ~/steamcmd/linux32/steamclient.so ~/.steam/sdk32/steamclient.so"
	run_steam "if [ -f ~/steamcmd/linux64/steamclient.so ]; then ln -sf ~/steamcmd/linux64/steamclient.so ~/.steam/sdk64/steamclient.so; fi"

	if [ ! -x "${steam_home}/l4d2server" ]; then
		log "Downloading LinuxGSM ${linuxgsm_version}"
		run_steam "cd ~ && curl -fsSL https://raw.githubusercontent.com/GameServerManagers/LinuxGSM/${linuxgsm_version}/linuxgsm.sh -o linuxgsm.sh && chmod +x linuxgsm.sh && ./linuxgsm.sh l4d2server && rm -f linuxgsm.sh"
	fi

	install_owned 755 "${repo_dir}/steamcmd-box86" "${steam_home}/bin/steamcmd-box86"
	install_owned 755 "${repo_dir}/steamcmd" "${steam_home}/bin/steamcmd"
	install_owned 755 "${repo_dir}/steamcmd-login-test.sh" "${steam_home}/bin/steamcmd-login-test.sh"
	install_owned 755 "${repo_dir}/l4d2-steamcmd-install.sh" "${steam_home}/bin/l4d2-steamcmd-install.sh"
	install_owned 755 "${repo_dir}/srcds-arm.sh" "${steam_home}/bin/srcds-arm.sh"
	install_owned 644 "${repo_dir}/linuxgsm/common.cfg" "${steam_home}/lgsm/config-lgsm/l4d2server/common.cfg"
	install_owned 644 "${repo_dir}/linuxgsm/l4d2server.cfg" "${steam_home}/lgsm/config-lgsm/l4d2server/l4d2server.cfg"
	install_owned 644 "${repo_dir}/linuxgsm-modules/check_system_requirements.sh" "${steam_home}/lgsm/modules/check_system_requirements.sh"
	install_owned 644 "${repo_dir}/linuxgsm-modules/check_deps.sh" "${steam_home}/lgsm/modules/check_deps.sh"
	install_if_missing 644 "${repo_dir}/game/l4d2server.cfg" "${steam_home}/serverfiles/left4dead2/cfg/l4d2server.cfg"
}

maybe_install_serverfiles() {
	if [ "${AUTO_INSTALL_L4D2:-0}" != "1" ]; then
		return
	fi

	if [ -x "${steam_home}/serverfiles/srcds_linux" ] || [ -x "${steam_home}/serverfiles/srcds_linux64" ]; then
		return
	fi

	if [ -z "${STEAM_USERNAME:-}" ] || [ -z "${STEAM_PASSWORD:-}" ]; then
		die "AUTO_INSTALL_L4D2=1 requires STEAM_USERNAME and STEAM_PASSWORD."
	fi

	log "Installing or updating L4D2 server files"
	sudo -u "${steam_linux_user}" -H \
		env STEAM_USERNAME="${STEAM_USERNAME}" STEAM_PASSWORD="${STEAM_PASSWORD}" \
		bash -lc '~/bin/l4d2-steamcmd-install.sh'
}

run_server_foreground() {
	local console_log="${steam_home}/log/console/l4d2server-console.log"

	if [ ! -x "${steam_home}/serverfiles/srcds_linux" ] && [ ! -x "${steam_home}/serverfiles/srcds_linux64" ]; then
		die "L4D2 server files are not installed. Set AUTO_INSTALL_L4D2=1 with Steam credentials, or exec into the container and run ~/bin/l4d2-steamcmd-install.sh as the steam user."
	fi

	log "Starting L4D2 server via LinuxGSM"
	run_steam "cd ~ && ./l4d2server start"
	mkdir -p "$(dirname "${console_log}")"
	touch "${console_log}"

	stop_server() {
		log "Stopping L4D2 server"
		run_steam "cd ~ && ./l4d2server stop" || true
		exit 0
	}

	trap stop_server TERM INT
	exec tail -F "${console_log}"
}

bootstrap_runtime
maybe_install_serverfiles

case "${1:-server}" in
	server)
		shift || true
		run_server_foreground
		;;
	*)
		exec "$@"
		;;
esac
