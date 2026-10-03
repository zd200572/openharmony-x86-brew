#!/bin/bash
# 生成 ruby 侧 x86 补丁归档 + 创建幂等补丁应用器 apply-brew-patches.sh
set -e
HB=/root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew
P=/root/ohos-x86/v2/patches

python3 /mnt/d/share/interesting/openharmony_x86_brew/v2/patch-ruby-x86.py

git -C "$HB" diff -- Library/Homebrew/os/linux/ld.rb \
                       Library/Homebrew/extend/os/linux/linkage_checker.rb \
                       Library/Homebrew/extend/os/linux/extend/ENV/super.rb \
                       Library/Homebrew/extend/os/linux/development_tools.rb \
                       > "$P/ruby-x86_64-ohos.patch"
cp "$P/ruby-x86_64-ohos.patch" /mnt/d/share/interesting/openharmony_x86_brew/v2/patches/
echo "=== ruby-x86_64-ohos.patch ==="
cat "$P/ruby-x86_64-ohos.patch"

cat > /root/ohos-x86/v2/apply-brew-patches.sh <<'EOF'
#!/bin/bash
# 幂等应用 v2/patches/*.patch 到 brew 仓库(brew update 会 checkout 发布 tag 抹掉一切本地修改)
HB=/root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew
for patch in /root/ohos-x86/v2/patches/*.patch; do
  [ -f "$patch" ] || continue
  if ( cd "$HB" && git apply --check --whitespace=nowarn "$patch" 2>/dev/null ); then
    ( cd "$HB" && git apply --whitespace=nowarn "$patch" ) && echo "[patch] applied: $(basename "$patch")"
  else
    echo "[patch] skipped (already applied or inapplicable): $(basename "$patch")"
  fi
done
EOF
cp /root/ohos-x86/v2/apply-brew-patches.sh /mnt/d/share/interesting/openharmony_x86_brew/v2/
echo MAKE_RUBY_PATCH_DONE
