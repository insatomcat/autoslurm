#!/usr/bin/env bash
set -euo pipefail

# Configure a Proxmox API service account for Autoslurm.
# Run this script on a Proxmox node as root.
#
# Optional env vars:
#   AUTOSLURM_PVE_USER=autoslurm
#   AUTOSLURM_PVE_REALM=pve
#   AUTOSLURM_PVE_TOKEN_ID=autoslurm
#   AUTOSLURM_PVE_ROLE=PVEAdmin
#   AUTOSLURM_TEMPLATE_VMID=9100
#   AUTOSLURM_RESET=1

PVE_USER="${AUTOSLURM_PVE_USER:-autoslurm}"
PVE_REALM="${AUTOSLURM_PVE_REALM:-pve}"
TOKEN_ID="${AUTOSLURM_PVE_TOKEN_ID:-autoslurm}"
ROLE="${AUTOSLURM_PVE_ROLE:-PVEAdmin}"
TEMPLATE_VMID="${AUTOSLURM_TEMPLATE_VMID:-9100}"
RESET="${AUTOSLURM_RESET:-0}"

USER_ID="${PVE_USER}@${PVE_REALM}"

if ! command -v pveum >/dev/null 2>&1; then
  echo "pveum not found. Run this script on a Proxmox host."
  exit 1
fi

if [ "${EUID}" -ne 0 ]; then
  echo "Run as root."
  exit 1
fi

if [ "${RESET}" = "1" ]; then
  echo "[reset] remove ACL/token/user if present"
  pveum acl delete / --users "${USER_ID}" --roles "${ROLE}" || true
  pveum acl delete "/vms/${TEMPLATE_VMID}" --users "${USER_ID}" --roles "${ROLE}" || true
  pveum user token remove "${USER_ID}" "${TOKEN_ID}" || true
  pveum user delete "${USER_ID}" || true
fi

echo "[1/4] ensure user exists: ${USER_ID}"
pveum user add "${USER_ID}" --comment "Autoslurm API user" || true

echo "[2/4] create/recreate token: ${USER_ID}!${TOKEN_ID}"
pveum user token remove "${USER_ID}" "${TOKEN_ID}" || true
TOKEN_OUTPUT="$(pveum user token add "${USER_ID}" "${TOKEN_ID}" --privsep 0 --expire 0)"

echo "[3/4] ensure ACL on / with role ${ROLE}"
pveum acl modify / --users "${USER_ID}" --roles "${ROLE}"

echo "[4/4] optional ACL on template /vms/${TEMPLATE_VMID}"
pveum acl modify "/vms/${TEMPLATE_VMID}" --users "${USER_ID}" --roles "${ROLE}" || true

TOKEN_SECRET="$(printf "%s\n" "${TOKEN_OUTPUT}" | awk '/^│ value/{print $3}')"

echo
echo "Done."
echo "Use in terraform.tfvars:"
echo "proxmox_api_token = \"${USER_ID}!${TOKEN_ID}=${TOKEN_SECRET}\""
echo
echo "Quick API test:"
echo "curl -k -i -H \"Authorization: PVEAPIToken=${USER_ID}!${TOKEN_ID}=${TOKEN_SECRET}\" https://127.0.0.1:8006/api2/json/version"
