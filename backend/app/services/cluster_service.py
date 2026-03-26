import threading
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

from app.config import Settings
from app.models import ClusterState, JobInfo, Operation
from app.services.runner import run_cmd, run_cmd_json


class ClusterService:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self._lock = threading.Lock()
        self._operation_lock = threading.Lock()
        self._last_operation: Operation | None = None
        self._last_scale_at: datetime | None = None
        self.root_dir = Path(__file__).resolve().parents[3]
        self.terraform_dir = self.root_dir / settings.terraform_dir
        self.ansible_dir = self.root_dir / settings.ansible_dir

    def _set_operation(self, op: Operation) -> None:
        with self._operation_lock:
            self._last_operation = op

    def get_last_operation(self) -> Operation | None:
        with self._operation_lock:
            return self._last_operation

    def _read_inventory_state(self) -> ClusterState:
        outputs = run_cmd_json(
            [self.settings.iac_bin, "output", "-json", "cluster_inventory"], cwd=self.terraform_dir
        )
        compute_nodes = outputs.get("compute_nodes", [])
        controller = outputs.get("controller", {})
        current_nodes = len(compute_nodes)
        return ClusterState(
            desired_nodes=current_nodes,
            current_nodes=current_nodes,
            controller=controller,
            compute_nodes=compute_nodes,
            last_operation=self.get_last_operation(),
        )

    def get_state(self) -> ClusterState:
        return self._read_inventory_state()

    def get_jobs(self) -> list[JobInfo]:
        try:
            out = run_cmd(
                ["squeue", "-h", "-o", "%i|%t|%j"],
                cwd=self.root_dir,
            )
        except RuntimeError:
            return []

        jobs: list[JobInfo] = []
        for line in out.splitlines():
            parts = line.split("|")
            if len(parts) == 3:
                jobs.append(JobInfo(id=parts[0], state=parts[1], name=parts[2]))
        return jobs

    def reconcile(self) -> Operation:
        operation = Operation(
            operation_id=str(uuid.uuid4()),
            action="reconcile",
            status="running",
            message="Reconciliation en cours",
            started_at=datetime.now(timezone.utc),
        )
        self._set_operation(operation)
        try:
            run_cmd([self.settings.iac_bin, "init", "-input=false"], cwd=self.terraform_dir)
            run_cmd([self.settings.iac_bin, "refresh"], cwd=self.terraform_dir)
            run_cmd(
                ["ansible-playbook", "playbooks/site.yml"],
                cwd=self.ansible_dir,
            )
            operation.status = "success"
            operation.message = "Reconciliation terminee"
        except RuntimeError as exc:
            operation.status = "failed"
            operation.message = str(exc)
        operation.finished_at = datetime.now(timezone.utc)
        self._set_operation(operation)
        return operation

    def scale_to(self, target_nodes: int) -> Operation:
        if target_nodes < self.settings.min_nodes or target_nodes > self.settings.max_nodes:
            raise ValueError(
                f"target_nodes doit etre entre {self.settings.min_nodes} et {self.settings.max_nodes}"
            )

        now = datetime.now(timezone.utc)
        if self._last_scale_at and (now - self._last_scale_at) < timedelta(
            seconds=self.settings.cooldown_seconds
        ):
            raise ValueError("Cooldown actif, reessayez plus tard")

        if not self._lock.acquire(blocking=False):
            raise ValueError("Une operation de scale est deja en cours")

        operation = Operation(
            operation_id=str(uuid.uuid4()),
            action="scale",
            target_nodes=target_nodes,
            status="running",
            message="Scale en cours",
            started_at=now,
        )
        self._set_operation(operation)

        try:
            run_cmd([self.settings.iac_bin, "init", "-input=false"], cwd=self.terraform_dir)
            run_cmd(
                [self.settings.iac_bin, "apply", "-auto-approve", f"-var=initial_compute_count={target_nodes}"],
                cwd=self.terraform_dir,
            )
            run_cmd(["ansible-playbook", "playbooks/site.yml"], cwd=self.ansible_dir)
            operation.status = "success"
            operation.message = "Scale termine avec succes"
            self._last_scale_at = datetime.now(timezone.utc)
        except RuntimeError as exc:
            operation.status = "failed"
            operation.message = str(exc)
        finally:
            operation.finished_at = datetime.now(timezone.utc)
            self._set_operation(operation)
            self._lock.release()
        return operation
