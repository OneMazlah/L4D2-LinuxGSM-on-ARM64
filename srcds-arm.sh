#!/bin/bash
set -euo pipefail

serverfiles="${L4D2_SERVERFILES:-${HOME}/serverfiles}"
wrapper_log="${HOME}/log/console/srcds-arm-wrapper.log"

cd "${serverfiles}"

# Mirror the runtime environment that srcds_run normally prepares.
export LD_LIBRARY_PATH=".:bin:${LD_LIBRARY_PATH:-}"
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

	printf '[%s] starting %s %s (BOX86_DYNAREC=%s BIGBLOCK=%s SAFEFLAGS=%s)\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "${runner}" "${binary}" "${BOX86_DYNAREC:-unset}" "${BOX86_DYNAREC_BIGBLOCK:-unset}" "${BOX86_DYNAREC_SAFEFLAGS:-unset}" >> "${wrapper_log}"
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
