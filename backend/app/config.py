import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    api_token: str = os.getenv("AUTOSLURM_API_TOKEN", "changeme")
    iac_bin: str = os.getenv("AUTOSLURM_IAC_BIN", "tofu")
    terraform_dir: str = os.getenv(
        "AUTOSLURM_TERRAFORM_DIR", "infra/terraform/proxmox"
    )
    ansible_dir: str = os.getenv("AUTOSLURM_ANSIBLE_DIR", "infra/ansible")
    min_nodes: int = int(os.getenv("AUTOSLURM_MIN_NODES", "1"))
    max_nodes: int = int(os.getenv("AUTOSLURM_MAX_NODES", "20"))
    cooldown_seconds: int = int(os.getenv("AUTOSLURM_COOLDOWN_SECONDS", "60"))
    pending_jobs_threshold: int = int(
        os.getenv("AUTOSLURM_PENDING_JOBS_THRESHOLD", "1")
    )
    idle_nodes_threshold: int = int(os.getenv("AUTOSLURM_IDLE_NODES_THRESHOLD", "2"))
