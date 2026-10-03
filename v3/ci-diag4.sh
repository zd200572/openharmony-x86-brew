#!/bin/bash
# 用 Windows GCM 传来的 token(经 GIT_TOKEN 环境变量)拉 CI job 日志;token 不打印
set -e
[ -n "$GIT_TOKEN" ] || { echo "NO_TOKEN"; exit 1; }
API=https://api.github.com/repos/zd200572/openharmony-x86-brew/actions
code=$(curl -sL --retry 2 -o /tmp/ci-job.log -w '%{http_code}' \
  -H "Authorization: Bearer $GIT_TOKEN" -H "Accept: application/vnd.github+json" \
  "$API/jobs/111173785626/logs")
echo "HTTP=$code size=$(wc -c < /tmp/ci-job.log)"
echo "=== 失败点(最后 70 行)==="
tail -70 /tmp/ci-job.log
