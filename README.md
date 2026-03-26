# Autoslurm

MVP d'autoscaling Slurm sur Proxmox.

## Composants

- `infra/terraform/proxmox`: provisioning des VM Debian 13 sur Proxmox (via OpenTofu).
- `infra/ansible`: configuration Slurm controller/compute.
- `backend`: API FastAPI pour scaler le cluster.
- `frontend`: interface web minimale de pilotage.
- `ops`: scripts d'orchestration locale.
- `docs`: architecture, prerequis et validation E2E.

## Demarrage rapide (MVP)

1. Configurer les variables d'environnement backend (token API, chemins Terraform/Ansible).
2. Configurer `infra/terraform/proxmox/terraform.tfvars` (fichier ignore par git).
3. Lancer le backend FastAPI.
4. Lancer le frontend statique.
5. Utiliser l'UI pour ajuster `target_nodes`.

## Orchestration automatique infra -> config

Le flux MVP est automatise:

1. OpenTofu cree/supprime les VM.
2. Le backend lit `cluster_inventory` via `tofu output -json`.
3. Le backend genere `infra/ansible/inventory/generated_hosts.yml`.
4. Le backend execute Ansible pour configurer/mettre a jour Slurm.

Aucune edition manuelle d'inventaire n'est requise. Il n'y a pas d'inventaire
statique versionne: l'inventaire est genere uniquement par le backend.

## API cluster lifecycle

- `POST /cluster/create`: creation complete du cluster (infra + config).
- `POST /cluster/scale`: ajustement du nombre de compute nodes.
- `POST /cluster/destroy`: destruction complete du cluster.
- `POST /cluster/reconcile`: reapplication de la configuration.

Le mode `controller + 1er compute sur la meme VM` est disponible via:

- payload API: `colocate_controller_and_first_compute`
- variable backend par defaut: `AUTOSLURM_COLOCATE_CONTROLLER_FIRST_COMPUTE`

## Reseau Proxmox dedie Slurm (recommande lab)

Pour eviter les problemes DHCP du LAN principal, creer un reseau dedie:

- Bridge: `vmbr1`
- Subnet: `172.22.0.0/24`
- Gateway Proxmox: `172.22.0.1`
- DHCP: `172.22.0.100-172.22.0.199`
- NAT sortant vers `vmbr0`

### Configuration rapide

1. Ajouter `vmbr1` dans `/etc/network/interfaces` (bridge sans port physique).
2. Activer `net.ipv4.ip_forward=1`.
3. Ajouter les regles NAT/FORWARD (`iptables`) pour `172.22.0.0/24 -> vmbr0`.
4. Installer/configurer `dnsmasq` sur `vmbr1` pour DHCP.
5. Dans `terraform.tfvars`, definir `vm_network_bridge = "vmbr1"`.

### Verification

- Dans une VM: `ip a`, `ip route`, `ping 172.22.0.1`, `ping 1.1.1.1`.
- Sur Proxmox: `qm guest cmd <VMID> network-get-interfaces`.

## Note sur qemu-guest-agent dans Debian 13 cloud image

Il est normal que l'image `genericcloud` Debian soit tres minimaliste et n'inclue pas
systematiquement `qemu-guest-agent` actif par defaut. Ce n'est pas une anomalie.

Pour Proxmox/OpenTofu, il faut donc preparer un template "golden" qui inclut:

- `qemu-guest-agent` installe
- service active: `systemctl enable --now qemu-guest-agent`
- cloud-init propre avant conversion en template

Sans cela, la VM peut etre creee mais les remontes IP/etat via agent restent instables.
