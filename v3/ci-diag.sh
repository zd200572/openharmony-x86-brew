#!/bin/bash
# 定位 CI 失败 step
API=https://api.github.com/repos/zd200572/openharmony-x86-brew/actions
cd /mnt/d/share/interesting/openharmony_x86_brew
SHA=$(git rev-parse HEAD)
echo "SHA=$SHA"
RUN_ID=$(curl -fsSL --retry 3 "$API/runs?head_sha=$SHA&per_page=1" | grep -oE '"id": [0-9]+' | head -1 | grep -oE '[0-9]+')
echo "RUN_ID=$RUN_ID"
curl -fsSL --retry 3 "$API/runs/$RUN_ID/jobs" > /tmp/jobs.json
grep -oE '"name": "[^"]+"|"conclusion": "[a-z]+"|"status": "[a-z_]+"' /tmp/jobs.json | head -60
echo "=== 各 step 结论(仅失败相关)==="
python3 - <<'EOF'
import json
d = json.load(open('/tmp/jobs.json'))
for job in d.get('jobs', []):
    print(f"JOB: {job['name']} -> {job['conclusion']}")
    for s in job.get('steps', []):
        mark = 'X' if s['conclusion'] == 'failure' else ' '
        print(f"  [{mark}] {s['name']}: {s['conclusion']}")
EOF
