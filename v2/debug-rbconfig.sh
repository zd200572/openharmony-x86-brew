#!/bin/bash
echo "=== rbconfig.rb 205-225 行 ==="
sed -n '205,225p' /root/ohos-x86/v2/ruby40-stage/opt/ruby40/lib/ruby/4.0.0/x86_64-linux-musl/rbconfig.rb
echo
echo "=== 文件里含 musl 的行(前10) ==="
grep -n "musl" /root/ohos-x86/v2/ruby40-stage/opt/ruby40/lib/ruby/4.0.0/x86_64-linux-musl/rbconfig.rb | head -10
echo
echo "=== 运行时真实值(chroot) ==="
chroot /root/ohos-x86/rootfs /bin/sh -c '/opt/ruby40/bin/ruby -e "puts RbConfig::CONFIG[\"host_os\"]; puts RbConfig::CONFIG[\"host\"]; puts RbConfig::CONFIG[\"host_cpu\"]"'
