# edge-bbrv3-kernel

Minimal Google BBRv3 kernel build for a single-purpose Debian 13 KVM VPS running sing-box VLESS REALITY.

No server secrets belong in this repository.

Build source: `google/bbr` branch `v3`.

Target profile:

- KVM VPS
- XFS root filesystem
- virtio_net
- virtio SCSI / sd disk path
- IPv4 + IPv6
- nftables with conntrack
- BBRv3 + fq
