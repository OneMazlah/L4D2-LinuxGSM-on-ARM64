#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
out_dir=${1:-/tmp/l4d2-arm-box86-shims}
cc=${CC:-i686-linux-gnu-gcc}
cxx=${CXX:-i686-linux-gnu-g++}

mkdir -p "${out_dir}"

"${cc}" -m32 -shared -fPIC \
  -Wl,--version-script="${script_dir}/isoc23-compat.map" \
  -o "${out_dir}/libisoc23compat.so" \
  "${script_dir}/isoc23-compat.c" \
  -pthread

# Keep these exports unversioned. box86 did not reliably resolve the versioned build.
"${cxx}" -m32 -shared -fPIC \
  -mstackrealign -mincoming-stack-boundary=2 -mpreferred-stack-boundary=2 \
  -o "${out_dir}/libtier0compat.so" \
  "${script_dir}/tier0-compat.cpp"

echo "Built:"
echo "  ${out_dir}/libisoc23compat.so"
echo "  ${out_dir}/libtier0compat.so"
echo
echo "Export checks:"
objdump -T "${out_dir}/libisoc23compat.so" | grep -E 'isoc23|mbsrtowcs|wmemset|pthread_cond_clockwait' || true
objdump -T "${out_dir}/libtier0compat.so" | grep -E 'GetCPUInformation|ConMsg|ConColorMsg|Warning|Error|AssertValid' || true
