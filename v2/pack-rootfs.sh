#!/bin/bash
# 卸载 bind 挂载 + 重打 rootfs tar(输出到 D 盘工作区)
set -e
ROOTFS=/root/ohos-x86/rootfs
OUT=/mnt/d/share/interesting/openharmony_x86_brew/v2/rootfs-v2.tar

umount $ROOTFS/dev $ROOTFS/proc $ROOTFS/sys 2>/dev/null || true

echo "=== 打包 rootfs ==="
tar -C $ROOTFS --numeric-owner -cf "$OUT" .
ls -lh "$OUT"
echo PACK_DONE
