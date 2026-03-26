# Architecture MVP

Le MVP se compose de 4 couches:

1. **Terraform/Proxmox**: cree et detruit les VM Debian 13.
2. **Ansible/Slurm**: configure controller et compute, rend les nodes operationnels.
3. **FastAPI**: expose les endpoints de scale, etat et reconcile.
4. **Frontend**: pilote `target_nodes` et affiche l'etat.

## Flux de scale up

1. Appel `POST /cluster/scale`.
2. `terraform apply` ajuste `initial_compute_count`.
3. `ansible-playbook site.yml` reconfigure Slurm.
4. `GET /cluster/state` retourne la nouvelle topologie.

## Flux de scale down

Dans ce MVP, le scale down repasse aussi par Terraform + reconfiguration Ansible.
Le drain Slurm detaille est planifie en etape d'amelioration.
