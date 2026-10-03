#!/bin/bash
set -u
R=/root/ohos-x86
echo "===== 1. libLLVM 里的 OHOS 字符串 ====="
strings "$R/rootfs/usr/lib/libLLVM-15.so" 2>/dev/null | grep -ci 'ohos' || true
strings "$R/rootfs/usr/lib/libLLVM-15.so" 2>/dev/null | grep -i 'ohos' | head -5
echo "===== 2. alpine clang 链接行(原样落盘) ====="
chroot "$R/rootfs" /bin/sh -c 'ohos-clang -### /tmp/probe.c -o /tmp/probe.bin' > /tmp/v3-link-A.txt 2>&1
tail -c 1500 /tmp/v3-link-A.txt
echo "===== 3. SDK clang 链接行(真值) ====="
"$R/ohos-sdk/linux/native/llvm/bin/x86_64-unknown-linux-ohos-clang" -### /tmp/probe.c -o /tmp/probe.bin > /tmp/v3-link-sdk.txt 2>&1 || true
tail -c 1500 /tmp/v3-link-sdk.txt
