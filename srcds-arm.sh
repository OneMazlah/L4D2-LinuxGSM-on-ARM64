#!/bin/bash
set -euo pipefail

serverfiles="${L4D2_SERVERFILES:-${HOME}/serverfiles}"
wrapper_log="${HOME}/log/console/srcds-arm-wrapper.log"

cd "${serverfiles}"

# Mirror the runtime environment that srcds_run normally prepares.
armhf_lib_paths="/usr/lib/arm-linux-gnueabihf:/lib/arm-linux-gnueabihf"
box86_x86_lib_paths="/usr/lib/box86-i386-linux-gnu"
export LD_LIBRARY_PATH=".:bin:${armhf_lib_paths}:${LD_LIBRARY_PATH:-}"
# Make both x86 runtime libraries bundled with box86 and armhf wrapped libraries
# visible for x86 plugin loads such as MetaMod and SourceMod.
export BOX86_LD_LIBRARY_PATH=".:bin:${box86_x86_lib_paths}:${armhf_lib_paths}:${BOX86_LD_LIBRARY_PATH:-}"
compat_preload="${serverfiles}/bin/libisoc23compat.so"
if [ -f "${compat_preload}" ]; then
	export BOX86_LD_PRELOAD="${compat_preload}:${BOX86_LD_PRELOAD:-}"
fi
export BOX86_DYNAREC=1
export BOX86_DYNAREC_BIGBLOCK=0
export BOX86_DYNAREC_SAFEFLAGS=2
export BOX86_SHOWSEGV=1

# Try to allow a core/apport crash report if the emulator or server aborts.
ulimit -c unlimited || true

mkdir -p "$(dirname "${wrapper_log}")"

run_binary() {
	local runner="$1"
	local binary="$2"
	shift 2

	printf '[%s] starting %s %s (BOX86_DYNAREC=%s BIGBLOCK=%s SAFEFLAGS=%s PRELOAD=%s)\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "${runner}" "${binary}" "${BOX86_DYNAREC:-unset}" "${BOX86_DYNAREC_BIGBLOCK:-unset}" "${BOX86_DYNAREC_SAFEFLAGS:-unset}" "${BOX86_LD_PRELOAD:-unset}" >> "${wrapper_log}"
	set +e
	"${runner}" "${binary}" "$@"
	local status=$?
	set -e
	printf '[%s] %s exited with status %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "${binary}" "${status}" >> "${wrapper_log}"
	return "${status}"
}

if [ -x "./srcds_linux64" ]; then
	run_binary box64 ./srcds_linux64 "$@"
	exit $?
fi

if [ -x "./srcds_linux" ]; then
	fileinfo="$(file -b ./srcds_linux || true)"
	case "${fileinfo}" in
		*"64-bit"*)
			run_binary box64 ./srcds_linux "$@"
			exit $?
			;;
		*)
			run_binary box86 ./srcds_linux "$@"
			exit $?
			;;
	esac
fi

printf 'srcds binary not found in %s\n' "${serverfiles}" >&2
exit 1
