#!/bin/bash
# V3 侦察第 2 轮:C++ 运行时/头文件/链接器/资源目录
set -u
R=/root/ohos-x86
S=$R/ohos-sdk/linux/native

echo "===== A. sysroot/usr/lib/x86_64-linux-ohos 全列表 ====="
ls "$S/sysroot/usr/lib/x86_64-linux-ohos"
echo "===== B. sysroot/usr/include 顶层(c++?) ====="
ls "$S/sysroot/usr/include" | grep -vE '^[a-z]+$' | head -30
ls -d "$S/sysroot/usr/include/c++" 2>&1
ls "$S/sysroot/usr/include/c++/v1" 2>/dev/null | head -10
echo "===== C. SDK llvm/lib/clang/15.0.4 内容 ====="
find "$S/llvm/lib/clang" -maxdepth 3 | head -30
echo "===== D. SDK llvm/bin 有无 lld/ar ====="
ls "$S/llvm/bin" | grep -E 'lld|ld\.|llvm-ar|llvm-ranlib' | head
echo "===== E. rootfs/usr/lib/llvm15 树 ====="
ls "$R/rootfs/usr/lib/llvm15"
ls "$R/rootfs/usr/lib/llvm15/bin" | head -50
ls -d "$R/rootfs/usr/lib/llvm15/lib/clang/"* 2>&1
echo "===== F. rootfs 内 binutils/ld? ====="
ls "$R/rootfs/bin" | grep -E '^(ld|ld\.|as|ar|ranlib|strip|objdump|nm)' || echo "(no binutils in /bin)"
ls "$R/rootfs/usr/lib/llvm15/bin" | grep -E 'ld|ar$|ranlib|nm' || echo "(no ld/ar in llvm15/bin)"
echo "===== G. rootfs/lib 里 C++ 运行时/unwind/z ====="
ls "$R/rootfs/lib" | grep -iE 'c\+\+|unwind|libz|libcrypto|libssl' || echo "(none)"
echo "===== H. install-alpine-clang.sh ====="
cat "$R/v2/install-alpine-clang.sh" 2>/dev/null || echo "(not on distro; check /mnt/d)"
echo "===== I. chroot 内 clang 实测 ====="
mountpoint -q "$R/rootfs/dev" || mount --bind /dev "$R/rootfs/dev"
mountpoint -q "$R/rootfs/proc" || mount --bind /proc "$R/rootfs/proc"
mountpoint -q "$R/rootfs/sys" || mount --bind /sys "$R/rootfs/sys"
chroot "$R/rootfs" /bin/sh -c '/bin/clang --version | head -2; echo PATH-test:; command -v ld as ar || true; echo "--- clang 默认资源目录:"; echo "#include <stdio.h>
int main(){return 42;}" > /tmp/t.c && /bin/clang /tmp/t.c -o /tmp/t.bin 2>&1 | head -20 && echo "compile-exit=$?" && /tmp/t.bin; echo "run-exit=$?"'
