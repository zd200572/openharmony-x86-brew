#!/bin/bash
for f in /mnt/d/share/interesting/openharmony_x86_brew/v3/stage-v3.sh \
         /mnt/d/share/interesting/openharmony_x86_brew/v3/verify-v3.sh \
         /mnt/d/share/interesting/openharmony_x86_brew/v3/ci-verify-v3.sh \
         /mnt/d/share/interesting/openharmony_x86_brew/v3/docker-e2e.sh \
         /mnt/d/share/interesting/openharmony_x86_brew/v3/pack-rootfs-v3.sh \
         /mnt/d/share/interesting/openharmony_x86_brew/v3/pour-test.sh \
         /mnt/d/share/interesting/openharmony_x86_brew/ci/build-image.sh \
         /mnt/d/share/interesting/openharmony_x86_brew/v2/apply-brew-patches.sh; do
  if bash -n "$f" 2>/dev/null; then echo "OK: $(basename "$f")"; else echo "FAIL: $f"; bash -n "$f"; fi
done
