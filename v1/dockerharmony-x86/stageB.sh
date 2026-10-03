#!/bin/bash
# V1 Stage B 驱动: 组件编译 -> curl -> rootfs -> 打包 (stageA 已完成)
set -e
set -o pipefail
WORKDIR=/root/ohos-x86
cd ${WORKDIR}

[ -d ${WORKDIR}/OpenHarmony-v7.0-Release/OpenHarmony ] || { echo "source tree missing"; exit 1; }

command -v patchelf >/dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y -qq patchelf
cp -f ${WORKDIR}/dockerharmony-x86/*.sh ${WORKDIR}/
cp -f ${WORKDIR}/dockerharmony/disable-hilog.patch ${WORKDIR}/
export SDK_NATIVE=${WORKDIR}/ohos-sdk/linux/native

echo "[$(date '+%F %T')] === build components (musl/libc++/toybox/mksh/openssl/zlib/selinux/pcre2, x86_64) ==="
bash ${WORKDIR}/build-components-x86.sh > ${WORKDIR}/build-components.log 2>&1 || {
  echo "[$(date '+%F %T')] COMPONENTS BUILD FAILED"; tail -50 ${WORKDIR}/build-components.log; exit 1; }
tail -20 ${WORKDIR}/build-components.log
echo "[$(date '+%F %T')] === build curl ==="
bash ${WORKDIR}/build-curl-x86.sh > ${WORKDIR}/build-curl.log 2>&1 || {
  echo "[$(date '+%F %T')] CURL BUILD FAILED"; tail -40 ${WORKDIR}/build-curl.log; exit 1; }
echo "[$(date '+%F %T')] === assemble rootfs ==="
bash ${WORKDIR}/build-rootfs-x86.sh > ${WORKDIR}/build-rootfs.log 2>&1 || {
  echo "[$(date '+%F %T')] ROOTFS FAILED"; tail -30 ${WORKDIR}/build-rootfs.log; exit 1; }
echo "[$(date '+%F %T')] === package tar ==="
tar -C ${WORKDIR}/rootfs -cf ${WORKDIR}/ohos-rootfs-x86_64.tar .
cp -f ${WORKDIR}/ohos-rootfs-x86_64.tar /mnt/d/share/interesting/openharmony_x86_brew/v1/
echo "[$(date '+%F %T')] STAGE B ALL DONE"
