# Creation automatique template Debian 13

Pour eviter la creation manuelle a chaque fois, utilise les scripts:

- `ops/create_debian13_template.sh`
- `ops/create_debian13_template_remote.sh`

## Prerequis

- Script execute sur un hote Proxmox (commande `qm` disponible).
- Un stockage Proxmox valide (ex: `local-lvm`).
- Un bridge reseau valide (ex: `vmbr0`).

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
bash /path/to/autoslurm/ops/create_debian13_template.sh
```

Le script SSH accepte les memes variables, en plus de:

- `PROXMOX_SSH_HOST` (obligatoire)
- `PROXMOX_SSH_USER` (optionnel, defaut `root`)

## Integration dans `terraform.tfvars`

Une fois le template cree:

```hcl
vm_template_id = 9000
```

## Source

La sequence automatisee suit l'approche de ce tutoriel:
[Tutoriel Debian 13 Cloud-Init sur Proxmox](https://legeekheureux.fr/tutoriel-creez-votre-template-debian-13-cloud-init-sur-proxmox-en-quelques-minutes/)
