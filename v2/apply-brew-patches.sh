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

# x86_64 泛化补丁(非 diff 形式, sed 幂等): Gemfile.lock 的 PLATFORMS 白名单只有 arm64 系,
# 容器(x86_64-linux-ohos/musl)跑 brew test 时 bundle install 直接拒绝。补两行平台。
LOCK="$HB/Library/Homebrew/Gemfile.lock"
if [ -f "$LOCK" ] && ! grep -q "x86_64-linux-ohos" "$LOCK"; then
  sed -i '/^  x86_64-linux-gnu$/a\  x86_64-linux-ohos\n  x86_64-linux-musl' "$LOCK"
  echo "[patch] Gemfile.lock PLATFORMS += x86_64-linux-{ohos,musl}"
else
  echo "[patch] Gemfile.lock 平台已含 x86_64(跳过)"
fi

# 平台解析一致性: 冻结模式要求 lock 对所有声明平台完整(原生 gem 如 prism 有平台变体),
# 用 bundle lock 正规补齐。成功后落标记文件(untracked, 不被 brew update 抹)避免重复联网。
if [ -f "$LOCK" ] && [ ! -f "$HB/.x86-lock-done" ]; then
  if chroot /root/ohos-x86/rootfs /bin/zsh -c '
    export HOME=/root PATH=/opt/ruby40/bin:/opt/git/bin:/bin:/usr/bin
    export SSL_CERT_FILE=/etc/ssl/certs/cacert.pem
    cd /storage/Users/currentUser/.harmonybrew/Homebrew/Library/Homebrew
    bundle lock --add-platform x86_64-linux-ohos --add-platform x86_64-linux-musl
  ' >/tmp/bundle-lock.log 2>&1; then
    touch "$HB/.x86-lock-done"
    echo "[patch] bundle lock --add-platform 完成(见 /tmp/bundle-lock.log)"
  else
    echo "[patch] bundle lock 失败(非致命, brew test 可能仍报 frozen), 日志 /tmp/bundle-lock.log:"
    tail -5 /tmp/bundle-lock.log
  fi
fi
