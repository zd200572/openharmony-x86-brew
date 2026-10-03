#!/bin/bash
# V1 Stage A: 下载 OHOS 7.0 全量源码 -> 解压 -> 立即删除压缩包(节省 71.6GB)
set -e
cd /root/ohos-x86
URL="https://repo.huaweicloud.com/openharmony/os/7.0-Release/code-v7.0-Release.tar.gz"
FREE_GB=$(df --output=avail -BG / | tail -1 | tr -dc 0-9)
echo "[$(date '+%F %T')] start, free=${FREE_GB}G"
aria2c -c -s 16 -x 16 -k 1M --summary-interval=120 -d . -o code-v7.0-Release.tar.gz "$URL"
echo "[$(date '+%F %T')] download done"
mkdir -p extract
tar xzf code-v7.0-Release.tar.gz -C extract
echo "[$(date '+%F %T')] extract done"
rm -f code-v7.0-Release.tar.gz
echo "[$(date '+%F %T')] tarball deleted, free=$(df --output=avail -BG / | tail -1 | tr -dc 0-9)G"
if [ -d extract/OpenHarmony ] && [ ! -d OpenHarmony-v7.0-Release ]; then
  mkdir -p OpenHarmony-v7.0-Release
  mv extract/OpenHarmony OpenHarmony-v7.0-Release/
  rmdir extract
fi
ls OpenHarmony-v7.0-Release/OpenHarmony 2>/dev/null | head -20
echo "[$(date '+%F %T')] stage A ALL DONE"
