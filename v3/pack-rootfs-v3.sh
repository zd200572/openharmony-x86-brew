#!/bin/bash
# V3 打包:卸载 bind 挂载 + 重打 rootfs tar(v3, 含容器内编译工具链与 zlib bottle 演示)
set -e
ROOTFS=/root/ohos-x86/rootfs
OUT=/mnt/d/share/interesting/openharmony_x86_brew/v3/rootfs-v3.tar

umount $ROOTFS/dev $ROOTFS/proc $ROOTFS/sys 2>/dev/null || true

echo "=== 打包 rootfs(v3) ==="
tar -C $ROOTFS --numeric-owner -cf "$OUT" .
ls -lh "$OUT"
echo PACK_V3_DONE
