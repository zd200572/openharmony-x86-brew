#!/bin/bash
# rbconfig target_os: linux-musl -> linux-ohos(运行时 host_os 由此展开, 使 OS.ohos? 为真)
set -e
STAGE_RBC=/root/ohos-x86/v2/ruby40-stage/opt/ruby40/lib/ruby/4.0.0/x86_64-linux-musl/rbconfig.rb

python3 - "$STAGE_RBC" <<'PYEOF'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
s = p.read_text()
s2, n = re.subn(r'(\["target_os"\] = )"linux-musl"', r'\1"linux-ohos"', s)
assert n == 1, f"expected 1 substitution on target_os, got {n}"
p.write_text(s2)
print("RBCONFIG_TARGET_OS_PATCHED")
PYEOF
grep -n '"target_os"\|"host_os"' "$STAGE_RBC"

echo "=== 重新组装 rootfs ruby40 ==="
bash /root/ohos-x86/v2/stage-brew.sh

echo "=== chroot 运行时验证 host_os ==="
cat > /root/ohos-x86/rootfs/root/check-os.rb <<'EOF'
require "rbconfig"
puts "host_os=#{RbConfig::CONFIG["host_os"]}"
puts "host=#{RbConfig::CONFIG["host"]}"
EOF
chroot /root/ohos-x86/rootfs /opt/ruby40/bin/ruby /root/check-os.rb
rm -f /root/ohos-x86/rootfs/root/check-os.rb
echo FIX_RBCONFIG_DONE
