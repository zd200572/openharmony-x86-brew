#!/bin/bash
# 在 rootfs 内准备最小本地 formula(hello.sh), 验证 brew install 全链路
# 在 chroot 外(distro 侧)运行: bash make-test-formula.sh
set -e
ROOTFS=/root/ohos-x86/rootfs
SRC=$ROOTFS/root/testsrc

rm -rf $SRC
mkdir -p $SRC/hello-1.0
cat > $SRC/hello-1.0/hello.sh <<'EOF'
#!/bin/sh
echo "Hello from Harmonybrew on $(uname -m) OHOS!"
EOF
chmod +x $SRC/hello-1.0/hello.sh
tar -C $SRC -czf $SRC/hello-1.0.tar.gz hello-1.0
SHA=$(sha256sum $SRC/hello-1.0.tar.gz | cut -d' ' -f1)
echo "sha256=$SHA"

cat > $SRC/hello.rb <<EOF
class Hello < Formula
  desc "Minimal local formula verifying brew install on OHOS x86_64"
  homepage "https://example.invalid"
  url "file:///root/testsrc/hello-1.0.tar.gz"
  sha256 "$SHA"
  version "1.0"

  def install
    bin.install "hello.sh"
  end

  test do
    assert_match "x86_64", shell_output("\#{bin}/hello.sh")
  end
end
EOF
echo TEST_FORMULA_READY
