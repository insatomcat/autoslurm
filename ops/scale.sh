#!/usr/bin/env bash
set -euo pipefail

if [ "${#}" -ne 1 ]; then
  echo "Usage: $0 <target_nodes>"
  exit 1
fi

TARGET_NODES="$1"
API_URL="${AUTOSLURM_API_URL:-http://127.0.0.1:8000}"
TOKEN="${AUTOSLURM_API_TOKEN:-changeme}"

curl -sS -X POST "${API_URL}/cluster/scale" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"target_nodes\": ${TARGET_NODES}}"
echo
