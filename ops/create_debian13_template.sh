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
HARDEN_IMAGE="${HARDEN_IMAGE:-1}"

if qm status "${VMID}" >/dev/null 2>&1; then
  echo "VMID ${VMID} already exists. Choose another VMID."
  exit 1
fi

echo "[1/7] Download Debian 13 cloud image"
curl -fL "${IMAGE_URL}" -o "${IMAGE_FILE}"

if [ "${HARDEN_IMAGE}" = "1" ]; then
  if ! command -v virt-customize >/dev/null 2>&1; then
    echo "virt-customize not found. Install guestfs-tools or set HARDEN_IMAGE=0."
    exit 1
  fi
  echo "[2/8] Harden image (install qemu-guest-agent)"
  virt-customize -a "${IMAGE_FILE}" \
    --install qemu-guest-agent,console-setup,keyboard-configuration,kbd \
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
echo "Template created successfully:"
echo "  VMID: ${VMID}"
echo "  Name: ${VMNAME}"
echo
echo "Use in tfvars:"
echo "  vm_template_id = ${VMID}"
