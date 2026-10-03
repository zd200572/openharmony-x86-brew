#!/bin/bash
set -u
R=/root/ohos-x86
echo "===== 1. alpine clang 二进制里有没有 OHOS 支持 ====="
strings "$R/rootfs/usr/lib/llvm15/bin/clang-15" 2>/dev/null | grep -c 'linux-ohos' || true
strings "$R/rootfs/usr/lib/llvm15/bin/clang-15" 2>/dev/null | grep -m5 -i 'ohos' || echo "(no ohos strings)"
echo "===== 2. 三元组解析对比(compile -v include 目录) ====="
cat > "$R/rootfs/tmp/probe.c" <<'EOF'
#include <stdio.h>
int main(){return 0;}
EOF
echo "--- A: -target x86_64-linux-ohos ---"
chroot "$R/rootfs" /bin/sh -c 'ohos-clang -v -c /tmp/probe.c -o /tmp/probe.o 2>&1 | sed -n "/search starts here/,/End of search/p"'
echo "--- B: -target x86_64-unknown-linux-ohos ---"
chroot "$R/rootfs" /bin/sh -c '/usr/lib/llvm15/bin/clang -target x86_64-unknown-linux-ohos --sysroot=/opt/ohos-sysroot -v -c /tmp/probe.c -o /tmp/probe.o 2>&1 | sed -n "/search starts here/,/End of search/p"'
echo "===== 3. 两种 target 的链接输入对比(-### 看链接行) ====="
echo "--- A: x86_64-linux-ohos ---"
chroot "$R/rootfs" /bin/sh -c 'ohos-clang -### /tmp/probe.c -o /tmp/probe.bin 2>&1 | tr " " "\n" | grep -E "Scrt1|crt1|crti|crtbegin|crtend|crtn|-lgcc|-lc|-lssp|--dynamic|ld\.|nostdlib|no-pie|pie" || true'
echo "--- B: x86_64-unknown-linux-ohos ---"
chroot "$R/rootfs" /bin/sh -c '/usr/lib/llvm15/bin/clang -target x86_64-unknown-linux-ohos --sysroot=/opt/ohos-sysroot -### /tmp/probe.c -o /tmp/probe.bin 2>&1 | tr " " "\n" | grep -E "Scrt1|crt1|crti|crtbegin|crtend|crtn|-lgcc|-lc|-lssp|--dynamic|ld\.|nostdlib|no-pie|pie" || true'
echo "===== 4. SDK clang 的链接输入(真值参照) ====="
"$R/ohos-sdk/linux/native/llvm/bin/x86_64-unknown-linux-ohos-clang" -### /tmp/probe.c -o /tmp/probe.bin 2>&1 | tr ' ' '\n' | grep -E 'Scrt1|crt1|crti|crtbegin|crtend|crtn|-lgcc|-lc|-lssp|--dynamic|ld\.|pie' || true
