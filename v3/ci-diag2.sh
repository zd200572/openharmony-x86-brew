#!/bin/bash
set -e
API=https://api.github.com/repos/zd200572/openharmony-x86-brew/actions
cd /mnt/d/share/interesting/openharmony_x86_brew
SHA=$(git rev-parse HEAD)
RUN_ID=$(curl -fsSL --retry 3 "$API/runs?head_sha=$SHA&per_page=1" | grep -oE '"id": [0-9]+' | head -1 | grep -oE '[0-9]+')
echo "RUN_ID=$RUN_ID"
curl -fsSL --retry 3 "$API/runs/$RUN_ID/jobs" > /tmp/ci-jobs.json
JOB_ID=$(grep -oE '"id": [0-9]+' /tmp/ci-jobs.json | head -1 | grep -oE '[0-9]+')
echo "JOB_ID=$JOB_ID"
code=$(curl -sL --retry 2 -o /tmp/ci-job.log -w '%{http_code}' "$API/jobs/$JOB_ID/logs")
echo "HTTP=$CODE size=$(wc -c < /tmp/ci-job.log)" 2>/dev/null || echo "http=$code size=$(wc -c < /tmp/ci-job.log)"
echo "=== 日志尾部 ==="
tail -c 4000 /tmp/ci-job.log
echo ""
echo "=== 失败上下文(搜 FAILED/Error/exit) ==="
grep -nE "FAILED|Error:|error:|exit code|fatal" /tmp/ci-job.log | tail -20 || true
