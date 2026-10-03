#!/bin/bash
# V2 调试: 检查 .harmonybrew 真实状态(bin 内容来源 / Homebrew 完整性 / brew 包装器)
HB=/root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew
echo "=== .harmonybrew 顶层 ==="
ls -la "$HB"/ | head -25
echo
echo "=== .harmonybrew/bin 文件数与前几项 ==="
ls "$HB"/bin 2>/dev/null | wc -l
ls -la "$HB"/bin 2>/dev/null | head -12
echo
echo "=== bin/bash 是什么 ==="
file "$HB"/bin/bash 2>&1
echo
echo "=== bin/brew 是否存在 ==="
ls -la "$HB"/bin/brew "$HB"/Homebrew/bin/brew 2>&1
echo
echo "=== Homebrew/ 完整性 ==="
ls "$HB"/Homebrew/ 2>&1
echo "--- .git ---"
ls -d "$HB"/Homebrew/.git 2>&1 && git -C "$HB"/Homebrew status 2>&1 | head -3
echo
echo "=== du 概览 ==="
du -sh "$HB"/bin "$HB"/Homebrew 2>/dev/null
echo
echo "=== os.sh 补丁痕迹 ==="
ls -la "$HB"/Homebrew/Library/Homebrew/utils/os.sh* 2>&1
grep -n "uname -m" "$HB"/Homebrew/Library/Homebrew/utils/os.sh 2>/dev/null | head -3
echo
echo "=== rootfs 是否有 glibc 运行时(Ubuntu bash 需要) ==="
ls /root/ohos-x86/rootfs/lib64/ 2>/dev/null | head -5
ls /root/ohos-x86/rootfs/lib/x86_64-linux-gnu/ 2>/dev/null | head -5
echo "=== 找 ld-linux-x86-64 ==="
find /root/ohos-x86/rootfs/lib /root/ohos-x86/rootfs/lib64 -maxdepth 2 -name "ld-linux*" 2>/dev/null
echo DEBUG_HB_DONE
