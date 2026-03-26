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
