#!/bin/bash
# V3 侦察第 4 轮:细节补齐
set -u
R=/root/ohos-x86
S=$R/ohos-sdk/linux/native

echo "===== A. SDK llvm/include 有无 c++/v1 ====="
ls -d "$S/llvm/include/c++/v1" 2>&1
ls "$S/llvm/include/c++/v1" 2>/dev/null | head -5
echo "===== B. rootfs/lib64 真实性与 libc++.so ====="
ls -ld "$R/rootfs/lib64"
ls -l "$R/rootfs/lib64/" | head -20
F="$R/rootfs/lib64/chipset-sdk-sp/libc++.so"
file "$F"
ls -l "$F"
echo "--- libc++ 需要的外部符号(UNWIND/abi) ---"
nm -D "$F" 2>/dev/null | grep -cE ' U ' 
nm -D "$F" 2>/dev/null | grep -E ' U .*(Unwind|__cxa)' | head -8
echo "===== C. libc++abi/libunwind 全盘找 ====="
find "$R/rootfs" -name 'libc++abi*' -o -name 'libunwind*' 2>/dev/null | head
find "$OH" -maxdepth 1 -name 'out' -prune -o -name 'libunwind.so' -print 2>/dev/null | head -3
OH=$R/OpenHarmony-v7.0-Release/OpenHarmony
find "$OH/out" -maxdepth 5 -name 'libunwind.so' 2>/dev/null | head -3
echo "===== D. V2 脚本惯例 ====="
echo "--- pack-rootfs.sh ---"
cat "$R/v2/pack-rootfs.sh" 2>/dev/null || cat /mnt/d/share/interesting/openharmony_x86_brew/v2/pack-rootfs.sh
echo "--- run-brew-install-test.sh ---"
cat /mnt/d/share/interesting/openharmony_x86_brew/v2/run-brew-install-test.sh
echo "===== E. rootfs /root/testsrc(V2 hello 包) ====="
ls -l "$R/rootfs/root/testsrc" 2>&1
echo "===== F. alpine make 包名 ====="
IDX=$(curl -fsSL -m 60 "https://dl-cdn.alpinelinux.org/alpine/v3.22/main/x86_64/")
echo "$IDX" | grep -oE 'href="make-[^"]*"' | head -3
echo "$IDX" | grep -oE 'href="binutils-libs[^"]*"' | head -3
echo "===== G. sync-all-to-distro.sh ====="
cat /mnt/d/share/interesting/openharmony_x86_brew/v2/sync-all-to-distro.sh 2>/dev/null
echo "===== H. ci/build-image.sh 头部 ====="
head -60 /mnt/d/share/interesting/openharmony_x86_brew/ci/build-image.sh
