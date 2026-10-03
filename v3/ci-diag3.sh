#!/bin/bash
# 公开通道取失败信息: check-runs annotations + summary
set -e
API=https://api.github.com/repos/zd200572/openharmony-x86-brew
cd /mnt/d/share/interesting/openharmony_x86_brew
SHA=$(git rev-parse HEAD)
curl -fsSL --retry 3 "$API/commits/$SHA/check-runs" -H "Accept: application/vnd.github+json" > /tmp/ci-checks.json
python3 - <<'EOF'
import json
d = json.load(open('/tmp/ci-checks.json'))
for cr in d.get('check_runs', []):
    print(f"CHECK: {cr['name']} -> {cr['conclusion']} (id={cr['id']})")
    out = cr.get('output', {})
    title = out.get('title')
    summary = (out.get('summary') or '')[:2000]
    print(f"  title: {title}")
    if summary: print(f"  summary: {summary}")
EOF
echo "=== annotations ==="
IDS=$(python3 -c "
import json
d=json.load(open('/tmp/ci-checks.json'))
print(' '.join(str(c['id']) for c in d.get('check_runs',[]) if c.get('conclusion')=='failure'))")
for id in $IDS; do
  curl -fsSL --retry 3 "$API/check-runs/$id/annotations" -H "Accept: application/vnd.github+json" | head -c 3000
  echo ""
done
