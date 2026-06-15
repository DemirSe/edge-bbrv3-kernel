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

set +o pipefail
yes "" | make LSMOD="$GITHUB_WORKSPACE/vps/lsmod-edge-prod.txt" localmodconfig
set -o pipefail
./scripts/kconfig/merge_config.sh -m .config "$GITHUB_WORKSPACE/config/edge-force.config"
make olddefconfig

# Prefer x86-64-v3 generic CPU target if this kernel tree supports it.
if grep -q '^config GENERIC_CPU3' arch/x86/Kconfig.cpu; then
  scripts/config --disable GENERIC_CPU || true
  scripts/config --enable GENERIC_CPU3 || true
  make olddefconfig
fi

# Hard strip after localmodconfig and merge_config.
for sym in WIRELESS WLAN CFG80211 MAC80211 BT SOUND SND DRM DRM_BOCHS USB USB_SUPPORT FLOPPY ATA ATA_PIIX ATA_GENERIC CDROM BLK_DEV_SR ISO9660_FS UDF_FS VMWARE_VMCI VSOCKETS VIRTIO_VSOCKETS TUN IPV6_SIT IPV6_GRE IPV6_TUNNEL IPV6_VTI NFT_COMPAT NETFILTER_XTABLES IP_TABLES IP_NF_IPTABLES IP_NF_FILTER IP_NF_MANGLE IP_NF_NAT IP6_NF_IPTABLES IP6_NF_FILTER IP6_NF_MANGLE ARP_TABLES DEBUG_INFO DEBUG_KERNEL GDB_SCRIPTS KGDB; do
  scripts/config --disable "$sym" || true
done

make olddefconfig

echo "Required config check:"
grep -E 'CONFIG_TCP_CONG_BBR=|CONFIG_DEFAULT_TCP_CONG=|CONFIG_NET_SCH_FQ=|CONFIG_GENERIC_CPU3=|CONFIG_VIRTIO_NET=|CONFIG_SCSI_VIRTIO=|CONFIG_XFS_FS=|CONFIG_IPV6=|CONFIG_NF_TABLES=|CONFIG_NFT_CT=' .config

for req in TCP_CONG_BBR NET_SCH_FQ VIRTIO_NET SCSI_VIRTIO XFS_FS IPV6 NF_TABLES NFT_CT; do
  grep -q "^CONFIG_${req}=y" .config || { echo "missing required CONFIG_${req}=y"; exit 1; }
done

for bad in WIRELESS WLAN BT SOUND SND DRM USB FLOPPY ATA CDROM BLK_DEV_SR ISO9660_FS UDF_FS VMWARE_VMCI VSOCKETS TUN IPV6_SIT IPV6_GRE IPV6_TUNNEL NFT_COMPAT NETFILTER_XTABLES IP_TABLES IP_NF_IPTABLES IP_NF_FILTER IP_NF_MANGLE IP_NF_NAT IP6_NF_IPTABLES IP6_NF_FILTER IP6_NF_MANGLE ARP_TABLES DEBUG_INFO; do
  if grep -q "^CONFIG_${bad}=y\|^CONFIG_${bad}=m" .config; then
    echo "forbidden CONFIG_${bad} still enabled"
    exit 1
  fi
done

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
