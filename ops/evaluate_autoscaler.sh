#!/usr/bin/env bash
set -euo pipefail

API_URL="${AUTOSLURM_API_URL:-http://127.0.0.1:8000}"
TOKEN="${AUTOSLURM_API_TOKEN:-changeme}"

curl -sS -X POST "${API_URL}/autoscaler/evaluate" \
  -H "Authorization: Bearer ${TOKEN}"
echo
