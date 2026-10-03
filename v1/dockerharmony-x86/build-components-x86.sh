#!/bin/bash
# build-components.sh 的 x86_64 适配版(基于 dockerharmony MIT 原版)
# 差异: --target-cpu x86_64; 源码由 stageA 预先下载解压
set -e

WORKDIR=$(pwd)
OHOS_DIR=${WORKDIR}/OpenHarmony-v7.0-Release/OpenHarmony
cd ${OHOS_DIR}

# Disable HiLog because the container does not include the HiLog service.
# (反向 dry-run 必须在 musl 目录内执行才能正确判断)
if (cd third_party/musl && patch -p1 --dry-run -R < ${WORKDIR}/disable-hilog.patch) >/dev/null 2>&1; then
  echo "hilog patch already applied, skip"
else
  (cd third_party/musl && patch -p1 --forward < ${WORKDIR}/disable-hilog.patch </dev/null) || echo "WARN: hilog patch not applied cleanly"
fi

# Build only the components needed for the container rootfs.
./build.sh --product-name rk3568 --target-cpu x86_64 \
    --build-target musl_install \
    --build-target libcpp_install \
    --build-target toybox \
    --build-target sh \
    --build-target libcrypto_shared \
    --build-target libssl_shared \
    --build-target shared_libz \
    --build-target libselinux \
    --build-target libpcre2
