#!/bin/bash
echo "=== build-ruby-x86.sh(3.4.11 配方) ==="
cat /root/ohos-x86/v2/build-ruby-x86.sh
echo
echo "=== vendor/bundle/ruby 里有什么 ==="
ls /root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew/Library/Homebrew/vendor/bundle/ruby/ 2>/dev/null
ls /root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew/Library/Homebrew/vendor/bundle/ruby/*/ 2>/dev/null | head -20
echo
echo "=== ruby_check_version_script.rb ==="
cat /root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew/Library/Homebrew/utils/ruby_check_version_script.rb 2>/dev/null
echo
echo "=== 探测华为云镜像上的 ruby 4.0.x ==="
for v in 4.0.7 4.0.6 4.0.5 4.0.4 4.0.3 4.0.2 4.0.1 4.0.0; do
  code=$(curl -s -o /dev/null -w "%{http_code}" -m 20 -I "https://mirrors.huaweicloud.com/ruby/ruby-${v}.tar.gz")
  echo "ruby-${v}.tar.gz -> HTTP ${code}"
done
