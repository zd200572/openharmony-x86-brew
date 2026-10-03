#!/bin/bash
set -e

WORKDIR=$(pwd)
OHOS_DIR=${WORKDIR}/OpenHarmony-v7.0-Release/OpenHarmony
OUT_DIR=${OHOS_DIR}/out/rk3568

# Build the container rootfs directly from the hb component build outputs,
# instead of extracting from the system image (which requires a full build).
rm -rf rootfs
mkdir -p rootfs/bin rootfs/lib rootfs/lib64/platformsdk rootfs/lib64/chipset-sdk-sp \
         rootfs/etc/ssl/certs rootfs/dev rootfs/proc rootfs/sys rootfs/mnt \
         rootfs/storage rootfs/opt rootfs/tmp rootfs/root

# --- bin: toybox + its applet symlinks ---
cp ${OUT_DIR}/thirdparty/toybox/toybox rootfs/bin/toybox
# Extract the applet list from the toybox BUILD.gn (same source the real build uses).
# Apply the same +/- adjustments as the BUILD.gn (chcon added, restorecon removed).
sed -n '/symlink_target_name = \[/,/^    \]/p' ${OHOS_DIR}/third_party/toybox/BUILD.gn \
    | grep -vE "symlink_target_name|^    \]" | sed 's/^[[:space:]]*"//;s/",$//' \
    | grep -v '^$' | grep -v '^\.\./' | grep -v '^restorecon$' > /tmp/toybox-applets.txt
while read -r applet; do
    [ -n "$applet" ] && ln -s toybox rootfs/bin/$applet
done < /tmp/toybox-applets.txt

# --- bin: mksh as /bin/sh ---
cp ${OUT_DIR}/thirdparty/mksh/sh rootfs/bin/sh

# --- lib: musl libc ---
cp ${OUT_DIR}/obj/build/common/musl/out/rk3568/common/common/libc/ld-musl-aarch64.so.1 rootfs/lib/
ln -s ../lib/ld-musl-aarch64.so.1 rootfs/lib64/libc.so

# --- etc: musl namespace config and ld path ---
cp ${OUT_DIR}/obj/build/common/musl/ld-musl-aarch64.path rootfs/etc/
for ini in ld-musl-namespace-aarch64.ini ld-musl-namespace-aarch64-flex.ini ld-musl-namespace-aarch64-New.ini; do
    cp ${OUT_DIR}/obj/third_party/musl/third_party/musl/config/${ini} rootfs/etc/
done

# --- lib64: openssl / zlib ---
cp ${OUT_DIR}/thirdparty/openssl/libcrypto_openssl.z.so rootfs/lib64/platformsdk/
cp ${OUT_DIR}/thirdparty/openssl/libssl_openssl.z.so rootfs/lib64/platformsdk/
cp ${OUT_DIR}/thirdparty/zlib/libshared_libz.z.so rootfs/lib64/platformsdk/

# --- lib64: selinux / pcre2 (real file under chipset-sdk-sp, symlink under platformsdk) ---
cp ${OUT_DIR}/thirdparty/selinux/libselinux.z.so rootfs/lib64/chipset-sdk-sp/
cp ${OUT_DIR}/thirdparty/pcre2/libpcre2.z.so rootfs/lib64/chipset-sdk-sp/
ln -s ../chipset-sdk-sp/libselinux.z.so rootfs/lib64/platformsdk/libselinux.z.so
ln -s ../chipset-sdk-sp/libpcre2.z.so rootfs/lib64/platformsdk/libpcre2.z.so

# --- lib64: SDK runtime libraries (libc++) ---
cp ${OUT_DIR}/obj/build/common/libcpp/prebuilts/clang/ohos/linux-x86_64/libcxx-ndk/lib/aarch64-linux-ohos/libc++_shared.so rootfs/lib64/
cp ${OUT_DIR}/obj/build/common/musl/prebuilts/clang/ohos/linux-x86_64/llvm/lib/aarch64-linux-ohos/libc++.so rootfs/lib64/chipset-sdk-sp/

# --- bin: curl (built by build-curl.sh) ---
cp curl-8.8.0-ohos-arm64/bin/curl rootfs/bin/
patchelf --replace-needed libssl.so.3 libssl_openssl.z.so rootfs/bin/curl
patchelf --replace-needed libcrypto.so.3 libcrypto_openssl.z.so rootfs/bin/curl
patchelf --replace-needed libz.so.1 libshared_libz.z.so rootfs/bin/curl

# --- etc: CA certificates ---
# Use the latest Mozilla CA bundle from curl.se. Fail hard if it cannot
# be downloaded, so the image never ships a stale certificate bundle.
mkdir -p rootfs/etc/ssl/certs
curl -fsSL --retry 3 -m 60 -o rootfs/etc/ssl/certs/cacert.pem https://curl.se/ca/cacert.pem

# Complete the FHS directory.
mkdir -p rootfs/usr rootfs/system
ln -s ../bin rootfs/usr/bin
ln -s ../lib rootfs/usr/lib
ln -s ../lib64 rootfs/usr/lib64
chmod 700 rootfs/root

# This NOTICE.txt file lists the third-party files included in this container image.
# When the container image changes, the content inside NOTICE.txt needs to be updated.
temp_a=$(mktemp)
temp_b=$(mktemp)
find rootfs -type f | sed 's/^rootfs//' | sort > $temp_a
cat NOTICE.txt | awk NF | grep '^/[a-zA-Z]' | sort > $temp_b
if ! cmp -s $temp_a $temp_b; then
    echo "NOTICE.txt does not match the files in the actual image, NOTICE.txt needs to be updated."
    diff -u $temp_a $temp_b
    exit 1
fi

# /etc/passwd and /etc/group are not third-party dependencies and are intentionally excluded from the NOTICE.txt file.
echo "root:x:0:0:root:/root:/bin/sh" > rootfs/etc/passwd
echo "root:x:0:" > rootfs/etc/group

cp NOTICE.txt rootfs/etc/
