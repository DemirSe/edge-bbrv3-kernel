#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export KBUILD_BUILD_USER=edge
export KBUILD_BUILD_HOST=github-actions
export KDEB_COMPRESS=xz

KERNEL_REPO="${KERNEL_REPO:-https://github.com/google/bbr.git}"
KERNEL_BRANCH="${KERNEL_BRANCH:-v3}"
LOCALVERSION="${LOCALVERSION:--edge-bbrv3}"
BUILD_ROOT="${BUILD_ROOT:-$PWD/work}"

mkdir -p "$BUILD_ROOT"
cd "$BUILD_ROOT"

git clone --depth 1 --branch "$KERNEL_BRANCH" "$KERNEL_REPO" linux-bbrv3
cd linux-bbrv3

cp "$GITHUB_WORKSPACE/config/base-debian-edge.config" .config
make olddefconfig

yes "" | make LSMOD="$GITHUB_WORKSPACE/vps/lsmod-edge-prod.txt" localmodconfig
./scripts/kconfig/merge_config.sh -m .config "$GITHUB_WORKSPACE/config/edge-force.config"
make olddefconfig

echo "Required config check:"
grep -E 'CONFIG_TCP_CONG_BBR=|CONFIG_DEFAULT_TCP_CONG=|CONFIG_NET_SCH_FQ=|CONFIG_VIRTIO_NET=|CONFIG_SCSI_VIRTIO=|CONFIG_XFS_FS=|CONFIG_IPV6=|CONFIG_NF_TABLES=|CONFIG_NFT_CT=' .config

scripts/config --disable DEBUG_INFO || true
scripts/config --disable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT || true
scripts/config --disable GDB_SCRIPTS || true
make olddefconfig

make -j"$(nproc)" bindeb-pkg LOCALVERSION="$LOCALVERSION" KDEB_PKGVERSION="1"

mkdir -p "$GITHUB_WORKSPACE/artifacts"
cp ../linux-image-*edge-bbrv3*.deb "$GITHUB_WORKSPACE/artifacts/"
cp ../linux-headers-*edge-bbrv3*.deb "$GITHUB_WORKSPACE/artifacts/" || true
cp .config "$GITHUB_WORKSPACE/artifacts/config-$(make kernelrelease)"
cd "$GITHUB_WORKSPACE/artifacts"
sha256sum * > SHA256SUMS
ls -lh
