#!/bin/bash
set -euo pipefail

steamuser="${STEAM_USERNAME:-}"
steampass="${STEAM_PASSWORD:-}"

if [ -z "${steamuser}" ]; then
	read -r -p "Steam username: " steamuser
fi

if [ -z "${steampass}" ]; then
	read -r -s -p "Steam password: " steampass
	echo
fi

if [ -z "${steamuser}" ] || [ -z "${steampass}" ]; then
	echo "Steam username and password are required." >&2
	exit 1
fi

echo "SteamCMD may ask for your Steam Guard code from email." >&2

exec "${HOME}/bin/steamcmd-box86" +login "${steamuser}" "${steampass}" +quit
