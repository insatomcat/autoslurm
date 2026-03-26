# Runbook MVP

## Prerequis

- OpenTofu >= 1.6
- Ansible >= 2.15
- Python >= 3.11
- Acces API Proxmox
- Template Debian 13 disponible sur Proxmox

## Configuration

1. Copier `infra/terraform/proxmox/terraform.tfvars.example` en `terraform.tfvars` (non versionne).
2. Renseigner les parametres Proxmox et la cle SSH.
3. Copier `backend/.env.example` en `.env` (ou exporter les variables).
4. Verifier `AUTOSLURM_IAC_BIN=tofu` dans l'environnement backend.

## Demarrage backend

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

## Demarrage frontend

```bash
cd frontend
python3 -m http.server 8080
```

## Verification E2E

1. Verifier l'etat initial (1 compute):
   - `./ops/state.sh`
2. Scale up a 3:
   - `./ops/scale.sh 3`
3. Re-verifier l'etat:
   - `./ops/state.sh`
4. Scale down a 1:
   - `./ops/scale.sh 1`
5. Evaluer autoscaler:
   - `./ops/evaluate_autoscaler.sh`

## Notes

- `POST /cluster/reconcile` permet de re-appliquer infra/configuration.
- `GET /cluster/jobs` depend de la disponibilite de `squeue`.
