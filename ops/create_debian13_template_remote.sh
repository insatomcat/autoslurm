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
HARDEN_IMAGE="${HARDEN_IMAGE:-1}"
INSTALL_SLURM_BASE_PACKAGES="${INSTALL_SLURM_BASE_PACKAGES:-1}"

echo "Connecting to ${PROXMOX_SSH_USER}@${PROXMOX_SSH_HOST}:${PROXMOX_SSH_PORT}..."

ssh -p "${PROXMOX_SSH_PORT}" "${PROXMOX_SSH_USER}@${PROXMOX_SSH_HOST}" \
  "VMID='${VMID}' VMNAME='${VMNAME}' STORAGE='${STORAGE}' BRIDGE='${BRIDGE}' CORES='${CORES}' MEMORY_MB='${MEMORY_MB}' DISK_SIZE='${DISK_SIZE}' DISK_FORMAT='${DISK_FORMAT}' EFI_FORMAT='${EFI_FORMAT}' IMAGE_URL='${IMAGE_URL}' IMAGE_FILE='${IMAGE_FILE}' HARDEN_IMAGE='${HARDEN_IMAGE}' INSTALL_SLURM_BASE_PACKAGES='${INSTALL_SLURM_BASE_PACKAGES}' bash -s" <<'EOF'
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

if [ "${HARDEN_IMAGE}" = "1" ]; then
  if ! command -v virt-customize >/dev/null 2>&1; then
    echo "virt-customize not found on remote host. Install guestfs-tools or set HARDEN_IMAGE=0."
    exit 1
  fi
  BASE_PACKAGES="qemu-guest-agent,console-setup,keyboard-configuration,kbd"
  if [ "${INSTALL_SLURM_BASE_PACKAGES}" = "1" ]; then
    BASE_PACKAGES="${BASE_PACKAGES},zip,unzip,zstd,slurmd,slurm-wlm,slurmctld,slurmdbd,podman,podman-compose,libmunge-dev,libmunge2,munge,build-essential,nfs-common,nfs-kernel-server,htop"
  fi
  echo "[2/8] Harden image (install base packages)"
  virt-customize -a "${IMAGE_FILE}" \
    --install "${BASE_PACKAGES}" \
    --run-command "systemctl enable qemu-guest-agent" \
    --run-command "truncate -s 0 /etc/machine-id" \
    --run-command "rm -f /var/lib/dbus/machine-id && ln -s /etc/machine-id /var/lib/dbus/machine-id" \
    --run-command "cloud-init clean --logs --seed || true" \
    --run-command "rm -f /etc/ssh/ssh_host_*" \
    --run-command "printf 'XKBMODEL=\"pc105\"\nXKBLAYOUT=\"fr\"\nXKBVARIANT=\"\"\nXKBOPTIONS=\"\"\nBACKSPACE=\"guess\"\n' > /etc/default/keyboard" \
    --run-command "printf 'KEYMAP=fr\n' > /etc/vconsole.conf" \
    --run-command "printf 'keyboard-configuration keyboard-configuration/layoutcode string fr\nkeyboard-configuration keyboard-configuration/modelcode string pc105\nkeyboard-configuration keyboard-configuration/variantcode string\nkeyboard-configuration keyboard-configuration/optionscode string\nconsole-setup console-setup/charmap47 select UTF-8\nconsole-setup console-setup/codeset47 select Lat15\nconsole-setup console-setup/fontsize-text47 select 16\nconsole-setup console-setup/fontface47 select Fixed\n' | debconf-set-selections" \
    --run-command "DEBIAN_FRONTEND=noninteractive dpkg-reconfigure keyboard-configuration" \
    --run-command "DEBIAN_FRONTEND=noninteractive dpkg-reconfigure console-setup" \
    --run-command "setupcon || true"
  STEP_CREATE="[3/8]"
  STEP_IMPORT="[4/8]"
  STEP_RESIZE="[5/8]"
  STEP_CPU="[6/8]"
  STEP_CI="[7/8]"
  STEP_TEMPLATE="[8/8]"
else
  STEP_CREATE="[2/7]"
  STEP_IMPORT="[3/7]"
  STEP_RESIZE="[4/7]"
  STEP_CPU="[5/7]"
  STEP_CI="[6/7]"
  STEP_TEMPLATE="[7/7]"
fi

echo "${STEP_CREATE} Create base VM"
qm create "${VMID}" \
  --name "${VMNAME}" \
  --net0 "virtio,bridge=${BRIDGE}" \
  --scsihw virtio-scsi-pci \
  --machine q35

echo "${STEP_IMPORT} Import disk image"
qm set "${VMID}" \
  --scsi0 "${STORAGE}:0,discard=on,ssd=1,format=${DISK_FORMAT},import-from=$(pwd)/${IMAGE_FILE}"

echo "${STEP_RESIZE} Resize and boot order"
qm disk resize "${VMID}" scsi0 "${DISK_SIZE}"
qm set "${VMID}" --boot order=scsi0

echo "${STEP_CPU} Configure CPU, RAM, UEFI, agent"
qm set "${VMID}" --cpu host --cores "${CORES}" --memory "${MEMORY_MB}"
qm set "${VMID}" --bios ovmf --efidisk0 "${STORAGE}:1,format=${EFI_FORMAT},efitype=4m,pre-enrolled-keys=1"
qm set "${VMID}" --agent enabled=1

echo "${STEP_CI} Attach cloud-init drive"
qm set "${VMID}" --ide2 "${STORAGE}:cloudinit"

echo "${STEP_TEMPLATE} Convert VM to template"
qm template "${VMID}"

echo
echo "Template created successfully on remote Proxmox host:"
echo "  VMID: ${VMID}"
echo "  Name: ${VMNAME}"
echo
echo "Use in tfvars:"
echo "  vm_template_id = ${VMID}"
EOF
