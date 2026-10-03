#!/bin/bash
# 补齐 alpine clang15 的 llvm15/bin 布局并验证
set -e
ROOTFS=/root/ohos-x86/rootfs
STAGE=/root/ohos-x86/v2/.deps/alpine-clang15/x

echo "=== apk 里 clang-15 的真实位置与链接指向 ==="
ls -la $STAGE/usr/bin/clang-15 $STAGE/usr/bin/clang++-15 2>/dev/null
ls $STAGE/usr/lib/llvm15/bin/ 2>/dev/null | head -8

echo "=== 拷贝 llvm15 目录(bin+lib) ==="
if [ -d $STAGE/usr/lib/llvm15 ]; then
  mkdir -p $ROOTFS/usr/lib
  cp -a $STAGE/usr/lib/llvm15 $ROOTFS/usr/lib/
fi

echo "=== chroot 验证 clang ==="
chroot $ROOTFS /bin/sh -c '/usr/bin/clang-15 --version 2>&1 | head -2'
echo "=== 缺失库检查 ==="
chroot $ROOTFS /bin/sh -c '/lib/ld-musl-x86_64.so.1 --list /usr/bin/clang-15 2>&1 | grep -iE "error|not found" || echo ALL_LIBS_OK'
echo FIX_ALPINE_CLANG_DONE
