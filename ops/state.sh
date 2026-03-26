#!/usr/bin/env bash
set -euo pipefail

API_URL="${AUTOSLURM_API_URL:-http://127.0.0.1:8000}"
TOKEN="${AUTOSLURM_API_TOKEN:-changeme}"

curl -sS "${API_URL}/cluster/state" \
  -H "Authorization: Bearer ${TOKEN}"
echo
