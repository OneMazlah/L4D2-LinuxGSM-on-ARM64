#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <sourcemod-root> <native-spcomp> <output-dir>" >&2
  exit 64
fi

sourcemod_root=$(cd -- "$1" && pwd)
spcomp=$(cd -- "$(dirname -- "$2")" && pwd)/$(basename -- "$2")
output_dir=$3
plugin_dir="${sourcemod_root}/plugins"
include_dir="${plugin_dir}/include"

if [[ ! -d "${plugin_dir}" ]]; then
  echo "missing plugin directory: ${plugin_dir}" >&2
  exit 1
fi

if [[ ! -d "${include_dir}" ]]; then
  echo "missing include directory: ${include_dir}" >&2
  exit 1
fi

if [[ ! -x "${spcomp}" ]]; then
  echo "missing executable spcomp: ${spcomp}" >&2
  exit 1
fi

mkdir -p "${output_dir}"

count=0
for source_file in "${plugin_dir}"/*.sp; do
  plugin_name=$(basename -- "${source_file}" .sp)
  "${spcomp}" "${source_file}" \
    -i "${include_dir}" \
    -o "${output_dir}/${plugin_name}.smx"
  count=$((count + 1))
done

echo "Built ${count} plugin(s) into ${output_dir}"
find "${output_dir}" -maxdepth 1 -type f -name '*.smx' | sort
