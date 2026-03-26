#!/usr/bin/env bash
set -euo pipefail

# Create a Debian 13 cloud-init template on Proxmox.
# Run this script directly on a Proxmox host (or over SSH on it).

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

if qm status "${VMID}" >/dev/null 2>&1; then
  echo "VMID ${VMID} already exists. Choose another VMID."
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
echo "Template created successfully:"
echo "  VMID: ${VMID}"
echo "  Name: ${VMNAME}"
echo
echo "Use in tfvars:"
echo "  vm_template_id = ${VMID}"
