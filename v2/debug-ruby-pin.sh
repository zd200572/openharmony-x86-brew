#!/bin/bash
HB=/root/ohos-x86/rootfs/storage/Users/currentUser/.harmonybrew/Homebrew
echo "=== portable-ruby-version 文件 ==="
cat "$HB/Library/Homebrew/vendor/portable-ruby-version" 2>/dev/null
echo
echo "=== vendor 目录 ==="
ls "$HB/Library/Homebrew/vendor/" 2>/dev/null
echo
echo "=== REQUIRED_RUBY 相关 ==="
grep -rn "REQUIRED_RUBY\|required_ruby\|4\.0\.7" "$HB/Library/Homebrew/brew.sh" "$HB/Library/Homebrew/vendor-install.rb" 2>/dev/null | head -20
echo
echo "=== brew.sh 里找 ruby 的逻辑(HOMEBREW_RUBY_PATH) ==="
grep -n -A6 "HOMEBREW_RUBY_PATH\|find-ruby\|which_ruby" "$HB/Library/Homebrew/brew.sh" 2>/dev/null | head -50
echo
echo "=== vendor-install.rb 头部 ==="
sed -n '1,50p' "$HB/Library/Homebrew/vendor-install.rb" 2>/dev/null
