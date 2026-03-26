# Creation automatique template Debian 13

Pour eviter la creation manuelle a chaque fois, utilise les scripts:

- `ops/create_debian13_template.sh`
- `ops/create_debian13_template_remote.sh`

## Prerequis

- Script execute sur un hote Proxmox (commande `qm` disponible).
- Un stockage Proxmox valide (ex: `local-lvm`).
- Un bridge reseau valide (ex: `vmbr0`).
- Pour hardening offline (recommande): `virt-customize` disponible (`guestfs-tools`).

## Utilisation rapide (directement sur l'hote Proxmox)

```bash
cd /root
bash /path/to/autoslurm/ops/create_debian13_template.sh
```

## Utilisation rapide (depuis ton poste via SSH)

```bash
cd /path/to/autoslurm
PROXMOX_SSH_HOST=10.0.0.10 \
PROXMOX_SSH_USER=root \
bash ./ops/create_debian13_template_remote.sh
```

Le script cree par defaut:

- `VMID=9000`
- `VMNAME=debian13-cloudinit`
- `STORAGE=local-lvm`
- `BRIDGE=vmbr0`
- `DISK_FORMAT=raw`
- `EFI_FORMAT=raw`
- `HARDEN_IMAGE=1` (installe `qemu-guest-agent` + active le service)
- `INSTALL_SLURM_BASE_PACKAGES=1` (installe une base de paquets Slurm/outils)

## Variables personnalisables

```bash
VMID=9100 \
VMNAME=debian13-cloudinit-v2 \
STORAGE=local-lvm \
BRIDGE=vmbr0 \
CORES=2 \
MEMORY_MB=2048 \
DISK_SIZE=25G \
DISK_FORMAT=raw \
EFI_FORMAT=raw \
HARDEN_IMAGE=1 \
INSTALL_SLURM_BASE_PACKAGES=1 \
bash /path/to/autoslurm/ops/create_debian13_template.sh
```

Le script SSH accepte les memes variables, en plus de:

- `PROXMOX_SSH_HOST` (obligatoire)
- `PROXMOX_SSH_USER` (optionnel, defaut `root`)

## Hardening image (qemu-guest-agent)

Par defaut, les scripts executent:

```bash
virt-customize -a <image>.qcow2 \
  --install qemu-guest-agent \
  --run-command "systemctl enable qemu-guest-agent"
```

En plus, le hardening nettoie l'identite clonee et prepare le layout clavier FR:

- reset `machine-id` (evite DHCP client-id duplique entre clones),
- `cloud-init clean`,
- regeneration des host keys SSH au boot,
- ecriture de `/etc/default/keyboard` avec `XKBLAYOUT="fr"`.

Si `INSTALL_SLURM_BASE_PACKAGES=1`, le template preinstalle aussi:

- `zip`, `unzip`, `zstd`
- `slurmd`, `slurm-wlm`, `slurmctld`, `slurmdbd`
- `podman`, `podman-compose`
- `libmunge-dev`, `libmunge2`, `munge`
- `build-essential`
- `nfs-common`, `nfs-kernel-server`
- `htop`

Si tu veux desactiver temporairement cette etape:

```bash
HARDEN_IMAGE=0 bash /path/to/autoslurm/ops/create_debian13_template.sh
```

## Integration dans `terraform.tfvars`

Une fois le template cree:

```hcl
vm_template_id = 9000
```

## Source

La sequence automatisee suit l'approche de ce tutoriel:
[Tutoriel Debian 13 Cloud-Init sur Proxmox](https://legeekheureux.fr/tutoriel-creez-votre-template-debian-13-cloud-init-sur-proxmox-en-quelques-minutes/)
