#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
output_dir="${script_dir}/dist"
package_prefix="sourcemod-box86-l4d2"
source_mode=""
source_path=""
version=""
wrapper_path="${script_dir}/srcds-arm.sh"

usage() {
  cat >&2 <<'EOF'
usage:
  make-sourcemod-release-archive.sh \
    --version <version> \
    --from-serverfiles <serverfiles-dir> \
    [--wrapper <srcds-arm.sh>] \
    [--output-dir <dir>]

  make-sourcemod-release-archive.sh \
    --version <version> \
    --from-staging <release-root> \
    [--wrapper <srcds-arm.sh>] \
    [--output-dir <dir>]

notes:
  --from-serverfiles packages a public-ready overlay from a live serverfiles tree.
  It scrubs common sensitive files such as admins and database configs.

  --from-staging packages an already-prepared release tree. The staging directory
  should already contain a top-level serverfiles/ directory.

outputs:
  <output-dir>/sourcemod-box86-l4d2-<version>.tar.gz
  <output-dir>/sourcemod-box86-l4d2-<version>.zip  (if the zip command exists)
  <output-dir>/checksums.txt
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

warn() {
  printf 'warning: %s\n' "$*" >&2
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

need_path() {
  local path="$1"
  [[ -e "${path}" ]] || die "missing path: ${path}"
}

abs_dir() {
  local path="$1"
  cd -- "${path}" && pwd
}

ensure_dir() {
  local path="$1"
  mkdir -p -- "${path}"
  cd -- "${path}" && pwd
}

write_admins_cfg_stub() {
  cat > "$1" <<'EOF'
/**
 * Public release stub.
 * Add custom admin entries here only after deployment.
 */
Admins
{
}
EOF
}

write_admins_simple_stub() {
  cat > "$1" <<'EOF'
// Public release stub.
// Add your own SteamIDs here after deployment.
// Example:
// "STEAM_1:0:123456" "99:z"
EOF
}

write_databases_stub() {
  cat > "$1" <<'EOF'
"Databases"
{
	"driver_default"		"sqlite"

	"default"
	{
		"driver"		"sqlite"
		"database"		"sourcemod-local"
	}

	"storage-local"
	{
		"driver"		"sqlite"
		"database"		"sourcemod-local"
	}
}
EOF
}

copy_tree() {
  local source="$1"
  local target="$2"

  mkdir -p "${target}"
  cp -a "${source}" "${target}/"
}

stage_from_serverfiles() {
  local serverfiles_root="$1"
  local package_root="$2"
  local addon_root="${serverfiles_root}/left4dead2/addons"
  local staged_serverfiles="${package_root}/serverfiles"
  local staged_addons="${staged_serverfiles}/left4dead2/addons"
  local staged_configs="${staged_addons}/sourcemod/configs"

  need_path "${serverfiles_root}/bin/libisoc23compat.so"
  need_path "${serverfiles_root}/bin/libtier0compat.so"
  need_path "${addon_root}/metamod"
  need_path "${addon_root}/sourcemod"
  need_path "${wrapper_path}"

  mkdir -p "${staged_serverfiles}/bin" "${staged_addons}"
  cp -a "${serverfiles_root}/bin/libisoc23compat.so" "${staged_serverfiles}/bin/"
  cp -a "${serverfiles_root}/bin/libtier0compat.so" "${staged_serverfiles}/bin/"
  copy_tree "${addon_root}/metamod" "${staged_addons}"
  copy_tree "${addon_root}/sourcemod" "${staged_addons}"

  if [[ -f "${addon_root}/metamod_x64.vdf.disabled" ]]; then
    cp -a "${addon_root}/metamod_x64.vdf.disabled" "${staged_addons}/"
  fi

  cp -a "${wrapper_path}" "${package_root}/srcds-arm.sh"

  rm -rf "${staged_addons}/sourcemod/data" "${staged_addons}/sourcemod/logs"
  rm -rf "${staged_addons}/sourcemod/scripting/testsuite"
  find "${staged_addons}/sourcemod" -maxdepth 1 -type d -name 'plugins.backup-*' -exec rm -rf {} +
  rm -f \
    "${staged_configs}/admins.cfg" \
    "${staged_configs}/admins_simple.ini" \
    "${staged_configs}/databases.cfg"

  mkdir -p "${staged_configs}"
  write_admins_cfg_stub "${staged_configs}/admins.cfg"
  write_admins_simple_stub "${staged_configs}/admins_simple.ini"
  write_databases_stub "${staged_configs}/databases.cfg"
}

stage_from_staging() {
  local staging_root="$1"
  local package_root="$2"

  need_path "${staging_root}/serverfiles"
  cp -a "${staging_root}/." "${package_root}/"

  if [[ -x "${wrapper_path}" && ! -e "${package_root}/srcds-arm.sh" ]]; then
    cp -a "${wrapper_path}" "${package_root}/srcds-arm.sh"
  fi
}

write_install_txt() {
  local target="$1"

  cat > "${target}/INSTALL.txt" <<EOF
${package_prefix}-${version}

This archive is a ready-build MetaMod + SourceMod overlay for L4D2 on ARM64 with box86.

Deploy:
1. Stop the server.
2. Copy serverfiles/bin/* into your L4D2 server root bin/.
3. Copy serverfiles/left4dead2/addons/* into left4dead2/addons/.
4. Copy srcds-arm.sh to your LinuxGSM wrapper path, usually /home/steam/bin/srcds-arm.sh.
5. Start the server and verify: meta version, sm version, sm plugins list, sm exts list.

Notes:
- admins.cfg, admins_simple.ini, and databases.cfg are stubs in public-ready archives.
- For L4D2 coop, keep mapchooser.smx, nextmap.smx, nominations.smx, randomcycle.smx,
  and rockthevote.smx disabled unless you replace them with L4D2-aware logic.
EOF
}

write_build_info() {
  local target="$1"
  local repo_commit=""

  if command -v git >/dev/null 2>&1; then
    repo_commit=$(git -C "${script_dir}" rev-parse --short HEAD 2>/dev/null || true)
  fi

  cat > "${target}/BUILD-INFO.txt" <<EOF
package=${package_prefix}
version=${version}
created_utc=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
source_mode=${source_mode}
source_path=${source_path}
wrapper_path=${wrapper_path}
repo_commit=${repo_commit}
EOF
}

create_archives() {
  local package_root="$1"
  local archive_base="$2"
  local tar_path="${output_dir}/${archive_base}.tar.gz"
  local zip_path="${output_dir}/${archive_base}.zip"
  local checksum_path="${output_dir}/checksums.txt"
  local package_parent

  package_parent=$(dirname -- "${package_root}")
  mkdir -p "${output_dir}"

  tar -C "${package_parent}" -czf "${tar_path}" "$(basename -- "${package_root}")"

  if command -v zip >/dev/null 2>&1; then
    (
      cd -- "${package_parent}"
      zip -qr "${zip_path}" "$(basename -- "${package_root}")"
    )
  else
    warn "zip command not found; skipping .zip asset"
  fi

  {
    (
      cd -- "${output_dir}"
      sha256sum "$(basename -- "${tar_path}")"
      if [[ -f "${zip_path}" ]]; then
        sha256sum "$(basename -- "${zip_path}")"
      fi
    )
  } > "${checksum_path}"

  printf 'Created:\n'
  printf '  %s\n' "${tar_path}"
  if [[ -f "${zip_path}" ]]; then
    printf '  %s\n' "${zip_path}"
  fi
  printf '  %s\n' "${checksum_path}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      shift
      [[ $# -gt 0 ]] || die "missing value for --version"
      version="$1"
      ;;
    --from-serverfiles)
      shift
      [[ $# -gt 0 ]] || die "missing value for --from-serverfiles"
      [[ -z "${source_mode}" ]] || die "choose only one of --from-serverfiles or --from-staging"
      source_mode="serverfiles"
      source_path=$(abs_dir "$1")
      ;;
    --from-staging)
      shift
      [[ $# -gt 0 ]] || die "missing value for --from-staging"
      [[ -z "${source_mode}" ]] || die "choose only one of --from-serverfiles or --from-staging"
      source_mode="staging"
      source_path=$(abs_dir "$1")
      ;;
    --output-dir)
      shift
      [[ $# -gt 0 ]] || die "missing value for --output-dir"
      output_dir=$(ensure_dir "$1")
      ;;
    --wrapper)
      shift
      [[ $# -gt 0 ]] || die "missing value for --wrapper"
      wrapper_path=$(cd -- "$(dirname -- "$1")" && pwd)/$(basename -- "$1")
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      die "unknown argument: $1"
      ;;
  esac
  shift
done

[[ -n "${version}" ]] || {
  usage
  die "missing --version"
}
[[ -n "${source_mode}" ]] || {
  usage
  die "missing release source; use --from-serverfiles or --from-staging"
}
[[ "${version}" =~ ^[A-Za-z0-9._-]+$ ]] || die "version must contain only letters, numbers, dots, underscores, or dashes"

need_cmd tar
need_cmd sha256sum

archive_base="${package_prefix}-${version}"
scratch_dir=$(mktemp -d)
trap 'rm -rf "${scratch_dir}"' EXIT
package_root="${scratch_dir}/${archive_base}"

mkdir -p "${package_root}"

case "${source_mode}" in
  serverfiles)
    stage_from_serverfiles "${source_path}" "${package_root}"
    ;;
  staging)
    stage_from_staging "${source_path}" "${package_root}"
    ;;
esac

write_install_txt "${package_root}"
write_build_info "${package_root}"
create_archives "${package_root}" "${archive_base}"
