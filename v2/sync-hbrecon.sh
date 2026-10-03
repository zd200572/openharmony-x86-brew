#!/bin/bash
set -e
WS=/mnt/d/share/interesting/openharmony_x86_brew
mkdir -p $WS/v2/hb-recon
cp -f /root/ohos-x86/hb-recon/install.sh $WS/v2/hb-recon/install.sh
sed -i 's/\r$//' $WS/v2/hb-recon/install.sh
echo "=== install.sh(补丁版)全文 ==="
cat $WS/v2/hb-recon/install.sh
echo SYNC_DONE
