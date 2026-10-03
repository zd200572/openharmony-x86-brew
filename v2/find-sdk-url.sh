#!/bin/bash
echo "=== bash history 里的 SDK 下载记录 ==="
grep -iE "ohos-sdk|native.*linux|sdk.*download|wget|aria2c|curl.*sdk" /root/.bash_history 2>/dev/null | grep -iE "http|huawei|mirror" | head -10
echo
echo "=== v0 目录(workspace) ==="
ls /mnt/d/share/interesting/openharmony_x86_brew/v0/ 2>/dev/null
grep -riE "ohos-sdk.*http|http.*ohos-sdk|L0-SDK|native-linux" /mnt/d/share/interesting/openharmony_x86_brew/v0/ /mnt/d/share/interesting/openharmony_x86_brew/docs/ 2>/dev/null | head -5
echo
echo "=== ohos-sdk 目录结构(确认版本) ==="
ls /root/ohos-x86/ohos-sdk/ /root/ohos-x86/ohos-sdk/linux/ 2>/dev/null
cat /root/ohos-x86/ohos-sdk/linux/native/oh-uni-package.json 2>/dev/null
echo
echo "=== install.sh 解压后的动作(post-extract) ==="
grep -n -A3 "brew.tar.gz\|tar.*xzf\|HOMEBREW_REPOSITORY)\|bin/brew" /mnt/d/share/interesting/openharmony_x86_brew/v2/hb-recon/install.sh | grep -vE "^\s*#" | tail -30
