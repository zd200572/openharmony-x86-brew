#!/bin/bash
echo "=== /root/ohos-x86 下所有 install.sh ==="
find /root/ohos-x86 -maxdepth 3 -name "install.sh" 2>/dev/null | head -10
echo
echo "=== brew.tar.gz 位置 ==="
find /root/ohos-x86 -maxdepth 4 -name "brew.tar.gz" 2>/dev/null | head -5
echo
echo "=== v2 目录全貌 ==="
ls /root/ohos-x86/v2/
echo
echo "=== dockerharmony 上游目录 ==="
ls /root/ohos-x86/dockerharmony/ 2>/dev/null | head -10
ls /root/ohos-x86/dockerharmony-x86/ 2>/dev/null | head -10
