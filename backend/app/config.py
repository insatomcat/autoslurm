import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    api_auth_enabled: bool = os.getenv("AUTOSLURM_API_AUTH_ENABLED", "false").lower() in (
        "1",
        "true",
        "yes",
    )
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
    ansible_private_key_file: str = os.getenv(
        "AUTOSLURM_ANSIBLE_PRIVATE_KEY_FILE", ""
    )
    ssh_bastion_host: str = os.getenv("AUTOSLURM_SSH_BASTION_HOST", "")
    ssh_bastion_user: str = os.getenv("AUTOSLURM_SSH_BASTION_USER", "root")
    ssh_bastion_port: int = int(os.getenv("AUTOSLURM_SSH_BASTION_PORT", "22"))
    ssh_bastion_private_key_file: str = os.getenv(
        "AUTOSLURM_SSH_BASTION_PRIVATE_KEY_FILE", ""
    )
    disable_ssh_known_hosts_check: bool = os.getenv(
        "AUTOSLURM_DISABLE_SSH_KNOWN_HOSTS_CHECK", "true"
    ).lower() in ("1", "true", "yes")
    colocate_controller_and_first_compute: bool = os.getenv(
        "AUTOSLURM_COLOCATE_CONTROLLER_FIRST_COMPUTE", "false"
    ).lower() in ("1", "true", "yes")
