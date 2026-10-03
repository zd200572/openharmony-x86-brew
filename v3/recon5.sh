#!/bin/bash
set -u
R=/root/ohos-x86
echo "===== A. chroot 里 grep 到底是谁 ====="
chroot "$R/rootfs" /bin/sh -c 'command -v grep; ls -la $(command -v grep); grep --help 2>&1 | head -2'
echo "--- binutils 解包区 usr/bin 是否有 grep/strings ---"
ls "$R/v3/.deps/alpine-v3/x/usr/bin/" | grep -E 'grep|strings|^ld$|^ar$|^as$|^make$'
echo "--- rootfs /bin 中 grep 与 strings ---"
ls -la "$R/rootfs/bin/grep" "$R/rootfs/bin/strings" 2>&1
echo "===== B. alltypes.h 在 sysroot 哪里 ====="
find "$R/rootfs/opt/ohos-sysroot/usr/include" -name 'alltypes.h' | head
echo "--- usr/include/bits? ---"
ls -la "$R/rootfs/opt/ohos-sysroot/usr/include/bits" 2>&1 | head -5
echo "--- aarch64 目录里有什么(对照) ---"
ls "$R/rootfs/opt/ohos-sysroot/usr/include/aarch64-linux-ohos" 2>&1 | head -8
echo "===== C. musl 头里谁 include bits/alltypes.h ====="
grep -rl "bits/alltypes.h" "$R/rootfs/opt/ohos-sysroot/usr/include" 2>/dev/null | head -5
echo "===== D. SDK wrapper 在宿主机如何解析(V0 可用)——宿主侧试编 ====="
S=$R/ohos-sdk/linux/native
printf '#include <stdio.h>\nint main(){return 0;}\n' > /tmp/probe.c
"$S/llvm/bin/x86_64-unknown-linux-ohos-clang" -v -c /tmp/probe.c -o /tmp/probe.o 2>&1 | grep -A4 '#include <...> search starts here'
echo "===== E. 容器侧 ohos-clang -v 对照 ====="
chroot "$R/rootfs" /bin/sh -c 'ohos-clang -v -c /tmp/probe.c -o /tmp/probe.o 2>&1 | grep -A6 "search starts here"'
