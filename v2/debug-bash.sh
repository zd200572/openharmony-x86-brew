#!/bin/bash
echo "=== brew wrapper shebang ==="
head -5 /root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew/bin/brew
echo
echo "=== rootfs 全盘找 bash/dash 可执行 ==="
find /root/ohos-x86/rootfs -name "bash*" -type f 2>/dev/null | head
find /root/ohos-x86/rootfs -name "sh" -o -name "dash" 2>/dev/null | grep -v proc | head
echo
echo "=== brew.sh shebang ==="
head -3 /root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew/Library/Homebrew/brew.sh 2>/dev/null
echo
echo "=== v2 缓存的 tarball ==="
ls -la /root/ohos-x86/v2/*.tar.* /root/ohos-x86/v2/.deps/*.tar.* /root/ohos-x86/.build/*.tar.* 2>/dev/null
echo
echo "=== install.sh 头部(怎么跑起来的) ==="
head -8 /root/ohos-x86/v2/hb-recon/install.sh 2>/dev/null
echo
echo "=== build-deps-x86.sh 配方(参考 URL/host 设置) ==="
cat /root/ohos-x86/v2/build-deps-x86.sh 2>/dev/null
echo DEBUG_BASH_DONE
