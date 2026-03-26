#!/usr/bin/env bash
set -euo pipefail

# Run Debian 13 template creation remotely on a Proxmox host over SSH.
#
# Required:
#   PROXMOX_SSH_HOST=<host-or-ip>
#
# Optional:
#   PROXMOX_SSH_USER=root
#   VMID=9000
#   VMNAME=debian13-cloudinit
#   STORAGE=local-lvm
#   BRIDGE=vmbr0
#   CORES=2
#   MEMORY_MB=2048
#   DISK_SIZE=25G
#   IMAGE_URL=...
#   IMAGE_FILE=...
# 
# Example:
# PROXMOX_SSH_HOST=127.0.0.1 \
# PROXMOX_SSH_PORT=2222 \
# PROXMOX_SSH_USER=root \
# VMID=9100 \
# VMNAME=debian13-cloudinit-v2 \
# STORAGE=local-lvm \
# BRIDGE=vmbr0 \
# DISK_FORMAT=raw \
# EFI_FORMAT=raw \
# bash ./ops/create_debian13_template_remote.sh


PROXMOX_SSH_HOST="${PROXMOX_SSH_HOST:-}"
PROXMOX_SSH_USER="${PROXMOX_SSH_USER:-root}"
PROXMOX_SSH_PORT="${PROXMOX_SSH_PORT:-22}"

if [ -z "${PROXMOX_SSH_HOST}" ]; then
  echo "Missing PROXMOX_SSH_HOST. Example:"
  echo "  PROXMOX_SSH_HOST=10.0.0.10 bash ./ops/create_debian13_template_remote.sh"
  exit 1
fi

VMID="${VMID:-9000}"
VMNAME="${VMNAME:-debian13-cloudinit}"
STORAGE="${STORAGE:-local-lvm}"
BRIDGE="${BRIDGE:-vmbr0}"
CORES="${CORES:-2}"
MEMORY_MB="${MEMORY_MB:-2048}"
DISK_SIZE="${DISK_SIZE:-25G}"
DISK_FORMAT="${DISK_FORMAT:-raw}"
EFI_FORMAT="${EFI_FORMAT:-raw}"
IMAGE_URL="${IMAGE_URL:-https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2}"
IMAGE_FILE="${IMAGE_FILE:-debian-13-genericcloud-amd64.qcow2}"

echo "Connecting to ${PROXMOX_SSH_USER}@${PROXMOX_SSH_HOST}:${PROXMOX_SSH_PORT}..."

ssh -p "${PROXMOX_SSH_PORT}" "${PROXMOX_SSH_USER}@${PROXMOX_SSH_HOST}" \
  "VMID='${VMID}' VMNAME='${VMNAME}' STORAGE='${STORAGE}' BRIDGE='${BRIDGE}' CORES='${CORES}' MEMORY_MB='${MEMORY_MB}' DISK_SIZE='${DISK_SIZE}' DISK_FORMAT='${DISK_FORMAT}' EFI_FORMAT='${EFI_FORMAT}' IMAGE_URL='${IMAGE_URL}' IMAGE_FILE='${IMAGE_FILE}' bash -s" <<'EOF'
set -euo pipefail

if ! command -v qm >/dev/null 2>&1; then
  echo "qm command not found on remote host."
  exit 1
fi

if qm status "${VMID}" >/dev/null 2>&1; then
  echo "VMID ${VMID} already exists on Proxmox. Choose another VMID."
  exit 1
fi

echo "[1/7] Download Debian 13 cloud image"
curl -fL "${IMAGE_URL}" -o "${IMAGE_FILE}"

echo "[2/7] Create base VM"
qm create "${VMID}" \
  --name "${VMNAME}" \
  --net0 "virtio,bridge=${BRIDGE}" \
  --scsihw virtio-scsi-pci \
  --machine q35

echo "[3/7] Import disk image"
qm set "${VMID}" \
  --scsi0 "${STORAGE}:0,discard=on,ssd=1,format=${DISK_FORMAT},import-from=$(pwd)/${IMAGE_FILE}"

echo "[4/7] Resize and boot order"
qm disk resize "${VMID}" scsi0 "${DISK_SIZE}"
qm set "${VMID}" --boot order=scsi0

echo "[5/7] Configure CPU, RAM, UEFI, agent"
qm set "${VMID}" --cpu host --cores "${CORES}" --memory "${MEMORY_MB}"
qm set "${VMID}" --bios ovmf --efidisk0 "${STORAGE}:1,format=${EFI_FORMAT},efitype=4m,pre-enrolled-keys=1"
qm set "${VMID}" --agent enabled=1

echo "[6/7] Attach cloud-init drive"
qm set "${VMID}" --ide2 "${STORAGE}:cloudinit"

echo "[7/7] Convert VM to template"
qm template "${VMID}"

echo
echo "Template created successfully on remote Proxmox host:"
echo "  VMID: ${VMID}"
echo "  Name: ${VMNAME}"
echo
echo "Use in tfvars:"
echo "  vm_template_id = ${VMID}"
EOF
