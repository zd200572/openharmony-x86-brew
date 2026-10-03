#!/bin/zsh
export HOME=/root
export PATH=/opt/ruby40/bin:/opt/git/bin:/opt/zsh/bin:/bin:/usr/bin
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_FROM_API=1
export HOMEBREW_INTERNAL_ALLOW_PACKAGES_FROM_PATHS=1
export HOMEBREW_DEVELOPER=1
export SSL_CERT_FILE=/etc/ssl/certs/cacert.pem
BREW=/storage/Users/currentUser/.harmonybrew/bin/brew
echo "--- env check in brew ruby ---"
$BREW ruby -e 'puts ENV["HOMEBREW_DEVELOPER"].inspect; puts ENV["HOMEBREW_INTERNAL_ALLOW_PACKAGES_FROM_PATHS"].inspect'
echo "--- pour with developer mode ---"
$BREW install /tmp/v3/zlib-1.3.1.x86_64_ohos.bottle.tar.gz 2>&1 | tail -6
echo "--- result ---"
$BREW list --versions zlib
ls /storage/Users/currentUser/.harmonybrew/Cellar/zlib/1.3.1/lib/ 2>&1
