#!/bin/bash
# GitHub Actions / 全新 Ubuntu 主机上的 dockerharmony:x86_64 全量构建
# 链路: 基底 rootfs(v1 12MB tar, 进仓库) -> OHOS SDK -> openssl/zlib/curl
#       -> zsh/git/ruby4.0.7 交叉编译 -> Alpine clang15 -> brew 引导 -> x86 补丁
#       -> chroot 端到端验证 -> tar -> docker import
# 用法: sudo -E bash ci/build-image.sh   (REPO_DIR 默认取脚本上两级目录)
set -euo pipefail

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
WORK=/root/ohos-x86
V2=$WORK/v2
ROOTFS=$WORK/rootfs
SDK_PUBLIC_TARBALL=https://repo.huaweicloud.com/openharmony/os/7.0-Release/ohos-sdk-windows_linux-public.tar.gz

[ "$(id -u)" = 0 ] || { echo "需要 root(sudo)运行"; exit 1; }
echo "=== [0/9] 环境 ==="
command -v curl >/dev/null || apt-get update -qq && apt-get install -y -qq curl xz-utils unzip aria2 >/dev/null
nproc; df -h / | tail -1

mkdir -p $WORK

echo "=== [1/9] 布置脚本与资产 ==="
rm -rf $V2 $WORK/dockerharmony-x86
cp -r "$REPO_DIR/v2" $V2
mkdir -p $WORK/dockerharmony-x86
cp -f "$REPO_DIR"/v1/dockerharmony-x86/*.sh $WORK/dockerharmony-x86/
chmod +x $V2/*.sh $WORK/dockerharmony-x86/*.sh

echo "=== [2/9] OHOS SDK(linux native)==="
if [ ! -d $WORK/ohos-sdk/linux/native ]; then
  cd $V2
  [ -f ohos-sdk-windows_linux-public.tar.gz ] || \
    aria2c -c -s 8 -x 8 -k 1M --summary-interval=60 -o ohos-sdk-windows_linux-public.tar.gz "$SDK_PUBLIC_TARBALL" \
    || curl -fSL --retry 3 -m 3600 -o ohos-sdk-windows_linux-public.tar.gz "$SDK_PUBLIC_TARBALL"
  # 外层 tar 解出 ohos-sdk/linux/native-*.zip(嵌套 zip, 与上游 build-curl.sh 一致), 需再 unzip 一层
  tar -xzf ohos-sdk-windows_linux-public.tar.gz -C $WORK
  rm -f ohos-sdk-windows_linux-public.tar.gz
  (cd $WORK/ohos-sdk/linux && unzip -q native-*.zip)
  # native 已就位, 嵌套包与 windows 侧不再需要(瘦身 actions/cache 归档)
  rm -rf $WORK/ohos-sdk/windows $WORK/ohos-sdk/linux/native-*.zip
fi
[ -d $WORK/ohos-sdk/linux/native ] || { echo "SDK 就位失败, 实际内容:"; ls -la $WORK/ohos-sdk/ $WORK/ohos-sdk/linux/ 2>/dev/null; exit 1; }
du -sh $WORK/ohos-sdk/linux/native

echo "=== [3/9] 基底 rootfs(V1 产物, 12MB)==="
rm -rf $ROOTFS
mkdir -p $ROOTFS
tar -C $ROOTFS -xf "$REPO_DIR/v1/ohos-rootfs-x86_64.tar"
# 基底 tar 的 dev/ 是空目录, 而步骤 7 的 chroot(stage-brew 校验等)不带 mount,
# git 启动需 open("/dev/null", O_RDWR) —— run2 37095610384 即死于此; 这里补齐设备节点。
# docker 运行时会自带 /dev, 镜像内这些节点会被运行时覆盖, 无副作用。
mkdir -p $ROOTFS/dev $ROOTFS/proc $ROOTFS/sys
[ -e $ROOTFS/dev/null    ] || mknod -m 666 $ROOTFS/dev/null    c 1 3
[ -e $ROOTFS/dev/zero    ] || mknod -m 666 $ROOTFS/dev/zero    c 1 5
[ -e $ROOTFS/dev/full    ] || mknod -m 666 $ROOTFS/dev/full    c 1 7
[ -e $ROOTFS/dev/random  ] || mknod -m 666 $ROOTFS/dev/random  c 1 8
[ -e $ROOTFS/dev/urandom ] || mknod -m 666 $ROOTFS/dev/urandom c 1 9
[ -e $ROOTFS/dev/tty     ] || mknod -m 600 $ROOTFS/dev/tty     c 5 0

echo "=== [4/9] openssl/zlib/curl(build-curl-x86, 自包含)==="
cd $V2
# build-curl-x86.sh 内部以 $V2/.build/ohos-sdk/ohos-sdk/linux/native 判定 SDK 是否就位;
# 软链到 $WORK 的 SDK, 避免 CI 里重新下载 3.1GB
mkdir -p $V2/.build/ohos-sdk
ln -sfn $WORK/ohos-sdk $V2/.build/ohos-sdk/ohos-sdk
SDK_NATIVE=$WORK/ohos-sdk/linux/native bash $WORK/dockerharmony-x86/build-curl-x86.sh \
  > $V2/ci-build-curl.log 2>&1 || { echo "CURL FAILED"; tail -40 $V2/ci-build-curl.log; exit 1; }
# stage-brew 期望 $WORK/.build/openssl-*, 软链对齐(build-curl 输出在 $V2/.build)
mkdir -p $WORK/.build
ln -sfn $V2/.build/openssl-3.0.9-ohos-x86_64 $WORK/.build/openssl-3.0.9-ohos-x86_64
ln -sfn $V2/.build/zlib-1.3.1-ohos-x86_64    $WORK/.build/zlib-1.3.1-ohos-x86_64

echo "=== [5/9] libyaml/ncurses/zsh/git(build-deps-x86)==="
bash $V2/build-deps-x86.sh > $V2/ci-build-deps.log 2>&1 || { echo "DEPS FAILED"; tail -40 $V2/ci-build-deps.log; exit 1; }
test -x $V2/zsh-stage/opt/zsh/bin/zsh || { echo "zsh stage 缺失"; exit 1; }
test -x $V2/git-stage/opt/git/bin/git || { echo "git stage 缺失"; exit 1; }

echo "=== [6/9] Ruby 4.0.7(host baseruby + 交叉, 含 rbconfig target_os 补丁)==="
bash $V2/build-ruby40-host-then-cross.sh > $V2/ci-build-ruby40.log 2>&1 || { echo "RUBY40 FAILED"; tail -40 $V2/ci-build-ruby40.log; exit 1; }
test -x $V2/ruby40-stage/opt/ruby40/bin/ruby || { echo "ruby40 stage 缺失"; exit 1; }

echo "=== [7/9] rootfs 组装 + Alpine clang15 + brew 引导 + x86 补丁 ==="
bash $V2/stage-brew.sh
bash $V2/install-alpine-clang.sh 2>&1 | grep -vE "^tar: Ignoring" | tail -5
bash $V2/brew-bootstrap.sh
bash $V2/apply-brew-patches.sh

echo "=== [8/9] chroot 端到端验证 ==="
mountpoint -q $ROOTFS/dev  || mount --bind /dev  $ROOTFS/dev
mountpoint -q $ROOTFS/proc || mount --bind /proc $ROOTFS/proc
mountpoint -q $ROOTFS/sys  || mount --bind /sys  $ROOTFS/sys

chroot $ROOTFS /bin/zsh -c '
export HOME=/root PATH=/opt/ruby40/bin:/opt/git/bin:/opt/zsh/bin:/bin:/usr/bin
BREW=/storage/Users/currentUser/.harmonybrew/bin/brew
echo "--- 四大件 ---"
ruby --version; git --version; zsh --version; curl --version | head -1
echo "--- clang ---"; /usr/bin/clang --version | head -1
echo "--- brew --version ---"; $BREW --version
echo "--- 本地 tap + install 端到端 ---"
mkdir -p /root/testsrc/hello-1.0
printf "#!/bin/sh\necho \"Hello from Harmonybrew on \$(uname -m) OHOS!\"\n" > /root/testsrc/hello-1.0/hello.sh
chmod +x /root/testsrc/hello-1.0/hello.sh
tar -C /root/testsrc -czf /root/testsrc/hello-1.0.tar.gz hello-1.0
SHA=$(sha256sum /root/testsrc/hello-1.0.tar.gz | cut -d" " -f1)
cat > /root/testsrc/hello.rb <<EOF
class Hello < Formula
  desc "Minimal local formula verifying brew install on OHOS x86_64"
  homepage "https://example.invalid"
  url "file:///root/testsrc/hello-1.0.tar.gz"
  sha256 "$SHA"
  version "1.0"
  def install
    bin.install "hello.sh"
  end
end
EOF
$BREW tap-new ohos/local >/dev/null 2>&1 || true
cp /root/testsrc/hello.rb /storage/Users/currentUser/.harmonybrew/Homebrew/Library/Taps/ohos/homebrew-local/Formula/hello.rb
$BREW install ohos/local/hello
/storage/Users/currentUser/.harmonybrew/opt/hello/bin/hello.sh
$BREW list
echo CHROOT_VERIFY_OK
'
umount $ROOTFS/dev $ROOTFS/proc $ROOTFS/sys 2>/dev/null || true

echo "=== [9/9] 打包镜像 ==="
IMAGE_TAR=$WORK/dockerharmony-x86_64.tar
tar -C $ROOTFS --numeric-owner -cf $IMAGE_TAR .
ls -lh $IMAGE_TAR
docker import --change 'CMD ["/bin/sh"]' $IMAGE_TAR dockerharmony:x86_64
docker run --rm dockerharmony:x86_64 /bin/sh -c '/storage/Users/currentUser/.harmonybrew/bin/brew --version && /storage/Users/currentUser/.harmonybrew/opt/hello/bin/hello.sh'

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "## dockerharmony:x86_64 构建成功"
    echo "- brew 7.0.6_3 + ruby 4.0.7 + zsh 5.9 + git 2.46.0 + Alpine clang 15"
    echo "- chroot 端到端验证通过(brew install 本地 tap)"
  } >> "$GITHUB_STEP_SUMMARY"
fi
echo CI_BUILD_ALL_OK
