#!/usr/bin/env bash

set -euo pipefail

WORKSPACE_ROOT=${WORKSPACE_ROOT:-/mnt/f/immich_ohos/mobile}
SOURCE_TPC_ROOT=${SOURCE_TPC_ROOT:-${WORKSPACE_ROOT}/third_party/tpc_c_cplusplus}
LOCAL_TPC_ROOT=${LOCAL_TPC_ROOT:-${HOME}/work/tpc_c_cplusplus}
LYCIUM_ROOT=${LYCIUM_ROOT:-${LOCAL_TPC_ROOT}/lycium}
SDK_ROOT=${SDK_ROOT:-${HOME}/ohos-sdk-linux-6.1.0.818/command-line-tools/sdk/default/openharmony}

if [ "$#" -eq 0 ]; then
  PACKAGES=(curl)
else
  PACKAGES=("$@")
fi

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

run_sudo() {
  if [ -n "${SUDO_PASSWORD:-}" ]; then
    printf '%s\n' "$SUDO_PASSWORD" | sudo -S -k -- "$@"
  else
    sudo -- "$@"
  fi
}

ensure_host_packages() {
  if command -v autopoint >/dev/null 2>&1; then
    return
  fi

  echo "[1/4] Installing missing host packages: autopoint gettext"
  run_sudo apt-get update
  run_sudo apt-get install -y autopoint gettext
}

sync_tpc_source() {
  echo "[2/4] Syncing tpc_c_cplusplus into the WSL workspace"

  if [ ! -d "${SOURCE_TPC_ROOT}/lycium" ]; then
    echo "Source tpc_c_cplusplus tree not found at ${SOURCE_TPC_ROOT}" >&2
    exit 1
  fi

  mkdir -p "$(dirname "${LOCAL_TPC_ROOT}")"

  if command -v rsync >/dev/null 2>&1; then
    mkdir -p "${LOCAL_TPC_ROOT}"
    rsync -a \
      --exclude='.git/' \
      --exclude='lycium/usr/' \
      --exclude='lycium/*.log' \
      --exclude='**/*-lycium_build.log' \
      "${SOURCE_TPC_ROOT}/" "${LOCAL_TPC_ROOT}/"
  else
    rm -rf "${LOCAL_TPC_ROOT}"
    mkdir -p "${LOCAL_TPC_ROOT}"
    cp -a "${SOURCE_TPC_ROOT}/." "${LOCAL_TPC_ROOT}/"
  fi
}

repair_sdk() {
  echo "[3/4] Verifying the WSL OHOS SDK"

  mkdir -p "${SDK_ROOT}"

  local needs_repair=0
  if [ ! -x "${SDK_ROOT}/native/llvm/bin/clang" ]; then
    needs_repair=1
  elif [ ! -e "${SDK_ROOT}/native/llvm/bin/ld.lld" ]; then
    needs_repair=1
  elif file "${SDK_ROOT}/native/llvm/bin/ld.lld" 2>/dev/null | grep -qi 'ASCII text'; then
    needs_repair=1
  fi

  if [ "${needs_repair}" -eq 1 ]; then
    cat >&2 <<EOF
The WSL OHOS SDK at ${SDK_ROOT} is missing or corrupted.
Install or restore a valid Linux OHOS SDK at SDK_ROOT before rerunning this script.
EOF
    exit 1
  fi

  mkdir -p "${SDK_ROOT}/native/llvm/bin"
  for tool in \
    aarch64-linux-ohos-clang \
    aarch64-linux-ohos-clang++ \
    arm-linux-ohos-clang \
    arm-linux-ohos-clang++
  do
    : > "${SDK_ROOT}/native/llvm/bin/${tool}.cmd"
  done
}

build_packages() {
  echo "[4/4] Building packages: ${PACKAGES[*]}"
  export OHOS_SDK="${SDK_ROOT}"
  cd "${LYCIUM_ROOT}"
  bash ./build.sh "${PACKAGES[@]}"
}

need_cmd bash
need_cmd cp
need_cmd file
need_cmd grep
need_cmd sudo

ensure_host_packages
sync_tpc_source
repair_sdk
build_packages

echo "Build finished successfully at ${LYCIUM_ROOT}"