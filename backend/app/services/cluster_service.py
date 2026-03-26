import threading
import uuid
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

from app.config import Settings
from app.models import ClusterState, JobInfo, Operation
from app.services.runner import run_cmd, run_cmd_json, run_cmd_stream


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

    def _append_step(self, operation: Operation, step: str) -> None:
        operation.steps.append(step)
        operation.message = step
        self._set_operation(operation)

    def _append_log(self, operation: Operation, line: str) -> None:
        operation.logs.append(line)
        if len(operation.logs) > 300:
            operation.logs = operation.logs[-300:]
        self._set_operation(operation)

    def get_last_operation(self) -> Operation | None:
        with self._operation_lock:
            return self._last_operation

    def _read_inventory_state(self) -> ClusterState:
        try:
            outputs = run_cmd_json(
                [self.settings.iac_bin, "output", "-json", "cluster_inventory"], cwd=self.terraform_dir
            )
        except RuntimeError:
            fallback = self._read_generated_inventory_state()
            if fallback is not None:
                controller, compute_nodes = fallback
                current_nodes = len(compute_nodes)
                return ClusterState(
                    desired_nodes=current_nodes,
                    current_nodes=current_nodes,
                    controller=controller,
                    compute_nodes=compute_nodes,
                    last_operation=self.get_last_operation(),
                )
            return ClusterState(
                desired_nodes=0,
                current_nodes=0,
                controller={},
                compute_nodes=[],
                last_operation=self.get_last_operation(),
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

    def _read_generated_inventory_state(self) -> tuple[dict, list[dict]] | None:
        inventory_path = self.ansible_dir / "inventory" / "generated_hosts.yml"
        if not inventory_path.exists():
            return None

        controller: dict = {}
        compute_nodes: list[dict] = []
        current_section: str | None = None
        current_host: str | None = None

        for raw_line in inventory_path.read_text(encoding="utf-8").splitlines():
            line = raw_line.rstrip()
            stripped = line.strip()
            if stripped == "slurm_controller:":
                current_section = "controller"
                current_host = None
                continue
            if stripped == "slurm_compute:":
                current_section = "compute"
                current_host = None
                continue
            if not stripped or stripped.endswith(": {}") or stripped == "hosts:":
                continue

            if current_section in {"controller", "compute"} and stripped.endswith(":"):
                host_name = stripped[:-1]
                if host_name != "hosts":
                    current_host = host_name
                continue

            if current_section and current_host and stripped.startswith("ansible_host:"):
                ip = stripped.split(":", 1)[1].strip()
                node = {"name": current_host, "ipv4": ip}
                if current_section == "controller" and not controller:
                    controller = node
                elif current_section == "compute":
                    compute_nodes.append(node)
                current_host = None

        if not controller and not compute_nodes:
            return None
        return controller, compute_nodes

    def _read_cluster_inventory_raw(self) -> dict:
        outputs = run_cmd_json(
            [self.settings.iac_bin, "output", "-json", "cluster_inventory"], cwd=self.terraform_dir
        )
        if not isinstance(outputs, dict):
            raise RuntimeError("Invalid cluster_inventory output format")
        return outputs

    def _run_bastion_cmd(self, remote_command: str) -> str:
        if not self.settings.ssh_bastion_host:
            raise RuntimeError("Bastion host not configured")
        cmd = [
            "ssh",
            "-p",
            str(self.settings.ssh_bastion_port),
            "-o",
            "StrictHostKeyChecking=no",
            "-o",
            "UserKnownHostsFile=/dev/null",
        ]
        if self.settings.ssh_bastion_private_key_file:
            cmd.extend(["-i", self.settings.ssh_bastion_private_key_file])
        cmd.append(f"{self.settings.ssh_bastion_user}@{self.settings.ssh_bastion_host}")
        cmd.append(remote_command)
        return run_cmd(cmd, cwd=self.root_dir)

    def _resolve_vm_id_by_name(self, vm_name: str) -> int | None:
        out = self._run_bastion_cmd("qm list")
        for line in out.splitlines():
            parts = line.split()
            if len(parts) >= 2 and parts[1] == vm_name:
                try:
                    return int(parts[0])
                except ValueError:
                    return None
        return None

    def _resolve_ipv4_by_vm_name(self, vm_name: str) -> str | None:
        vmid = self._resolve_vm_id_by_name(vm_name)
        if vmid is None:
            return None
        out = self._run_bastion_cmd(f"qm guest cmd {vmid} network-get-interfaces")
        data = json.loads(out) if out else []
        for iface in data:
            for addr in iface.get("ip-addresses", []):
                ip = addr.get("ip-address")
                ip_type = addr.get("ip-address-type")
                if ip_type == "ipv4" and ip and not ip.startswith("127."):
                    return ip
        return None

    def _resolve_inventory_ips(self, cluster_inventory: dict) -> dict:
        if not self.settings.ssh_bastion_host:
            return cluster_inventory
        controller = cluster_inventory.get("controller", {})
        compute_nodes = cluster_inventory.get("compute_nodes", [])

        if controller.get("name"):
            resolved_ip = self._resolve_ipv4_by_vm_name(controller["name"])
            if resolved_ip:
                controller["ipv4"] = resolved_ip

        for node in compute_nodes:
            name = node.get("name")
            if not name:
                continue
            resolved_ip = self._resolve_ipv4_by_vm_name(name)
            if resolved_ip:
                node["ipv4"] = resolved_ip

        cluster_inventory["controller"] = controller
        cluster_inventory["compute_nodes"] = compute_nodes
        return cluster_inventory

    def _validate_no_duplicate_ips(self, cluster_inventory: dict) -> None:
        ip_to_names: dict[str, set[str]] = {}

        controller = cluster_inventory.get("controller", {})
        ctrl_ip = controller.get("ipv4")
        ctrl_name = controller.get("name")
        if ctrl_ip and ctrl_name:
            ip_to_names.setdefault(ctrl_ip, set()).add(ctrl_name)

        for node in cluster_inventory.get("compute_nodes", []):
            ip = node.get("ipv4")
            name = node.get("name")
            if ip and name:
                ip_to_names.setdefault(ip, set()).add(name)

        # Duplicate IP is only an error when used by different VM names.
        duplicates = [ip for ip, names in ip_to_names.items() if len(names) > 1]
        if duplicates:
            raise RuntimeError(
                "Duplicate VM IPs detected across different VMs: "
                + ", ".join(sorted(duplicates))
            )

    def _build_apply_command(self, target_nodes: int, colocate: bool) -> list[str]:
        return [
            self.settings.iac_bin,
            "apply",
            "-auto-approve",
            f"-var=initial_compute_count={target_nodes}",
            f"-var=colocate_controller_and_first_compute={'true' if colocate else 'false'}",
        ]

    def _render_ansible_inventory(self, cluster_inventory: dict) -> str:
        controller = cluster_inventory.get("controller", {})
        controller_name = controller.get("name")
        controller_ip = controller.get("ipv4")
        compute_nodes = cluster_inventory.get("compute_nodes", [])

        if not controller_name or not controller_ip:
            raise RuntimeError("Controller data missing in cluster inventory")

        vars_lines: list[str] = [
            "    ansible_user: debian",
            "    cluster_name: autoslurm",
            "    slurm_cluster_name: autoslurm",
        ]

        if self.settings.ansible_private_key_file:
            vars_lines.append(
                f"    ansible_ssh_private_key_file: {self.settings.ansible_private_key_file}"
            )

        if self.settings.ssh_bastion_host:
            proxy_target = (
                f"{self.settings.ssh_bastion_user}@"
                f"{self.settings.ssh_bastion_host}"
            )
            if self.settings.ssh_bastion_private_key_file:
                proxy = (
                    "-o ProxyCommand=\"ssh "
                    f"-i {self.settings.ssh_bastion_private_key_file} "
                    f"-p {self.settings.ssh_bastion_port} "
                    "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "
                    f"-W %h:%p {proxy_target}\""
                )
            else:
                proxy = f"-o ProxyJump={proxy_target}:{self.settings.ssh_bastion_port}"
            common_args = [proxy]
        else:
            common_args = []

        if self.settings.disable_ssh_known_hosts_check:
            common_args.extend(
                [
                    "-o StrictHostKeyChecking=no",
                    "-o UserKnownHostsFile=/dev/null",
                ]
            )

        if common_args:
            vars_lines.append(f"    ansible_ssh_common_args: '{' '.join(common_args)}'")

        lines: list[str] = ["all:", "  vars:", *vars_lines, "  children:", "    slurm_controller:", "      hosts:", f"        {controller_name}:", f"          ansible_host: {controller_ip}", "    slurm_compute:", "      hosts:"]

        for node in compute_nodes:
            name = node.get("name")
            ip = node.get("ipv4")
            if not name or not ip:
                continue
            lines.extend(
                [
                    f"        {name}:",
                    f"          ansible_host: {ip}",
                ]
            )

        if not compute_nodes:
            lines.append("        {}")

        return "\n".join(lines) + "\n"

    def _sync_ansible_inventory(self) -> None:
        cluster_inventory = self._read_cluster_inventory_raw()
        cluster_inventory = self._resolve_inventory_ips(cluster_inventory)
        self._validate_no_duplicate_ips(cluster_inventory)
        content = self._render_ansible_inventory(cluster_inventory)
        generated_path = self.ansible_dir / "inventory" / "generated_hosts.yml"
        generated_path.parent.mkdir(parents=True, exist_ok=True)
        generated_path.write_text(content, encoding="utf-8")

    def _write_empty_inventory(self) -> None:
        content = (
            "all:\n"
            "  vars:\n"
            "    ansible_user: debian\n"
            "    cluster_name: autoslurm\n"
            "    slurm_cluster_name: autoslurm\n"
            "  children:\n"
            "    slurm_controller:\n"
            "      hosts: {}\n"
            "    slurm_compute:\n"
            "      hosts: {}\n"
        )
        generated_path = self.ansible_dir / "inventory" / "generated_hosts.yml"
        generated_path.parent.mkdir(parents=True, exist_ok=True)
        generated_path.write_text(content, encoding="utf-8")

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
            steps=["Reconciliation demarree"],
            started_at=datetime.now(timezone.utc),
        )
        self._set_operation(operation)
        try:
            self._append_step(operation, "OpenTofu init")
            run_cmd([self.settings.iac_bin, "init", "-input=false"], cwd=self.terraform_dir)
            self._append_step(operation, "OpenTofu refresh")
            run_cmd([self.settings.iac_bin, "refresh"], cwd=self.terraform_dir)
            self._append_step(operation, "Generation inventaire Ansible")
            self._sync_ansible_inventory()
            self._append_step(operation, "Execution playbook Ansible")
            run_cmd_stream(
                ["ansible-playbook", "-i", "inventory/generated_hosts.yml", "playbooks/site.yml"],
                cwd=self.ansible_dir,
                on_line=lambda line: self._append_log(operation, line),
            )
            operation.status = "success"
            operation.message = "Reconciliation terminee"
            operation.steps.append("Reconciliation terminee")
        except RuntimeError as exc:
            operation.status = "failed"
            operation.message = str(exc)
            operation.steps.append("Echec reconciliation")
        operation.finished_at = datetime.now(timezone.utc)
        self._set_operation(operation)
        return operation

    def create_cluster(self, target_nodes: int, colocate: bool) -> Operation:
        operation = Operation(
            operation_id=str(uuid.uuid4()),
            action="create",
            target_nodes=target_nodes,
            status="running",
            message="Creation du cluster en cours",
            steps=["Creation cluster demarree"],
            started_at=datetime.now(timezone.utc),
        )
        self._set_operation(operation)
        try:
            self._append_step(operation, "OpenTofu init")
            run_cmd([self.settings.iac_bin, "init", "-input=false"], cwd=self.terraform_dir)
            self._append_step(operation, "OpenTofu apply")
            run_cmd(self._build_apply_command(target_nodes, colocate), cwd=self.terraform_dir)
            self._append_step(operation, "Generation inventaire Ansible")
            self._sync_ansible_inventory()
            self._append_step(operation, "Execution playbook Ansible")
            run_cmd_stream(
                ["ansible-playbook", "-i", "inventory/generated_hosts.yml", "playbooks/site.yml"],
                cwd=self.ansible_dir,
                on_line=lambda line: self._append_log(operation, line),
            )
            operation.status = "success"
            operation.message = "Cluster cree avec succes"
            operation.steps.append("Creation cluster terminee")
            self._last_scale_at = datetime.now(timezone.utc)
        except RuntimeError as exc:
            operation.status = "failed"
            operation.message = str(exc)
            operation.steps.append("Echec creation cluster")
        operation.finished_at = datetime.now(timezone.utc)
        self._set_operation(operation)
        return operation

    def destroy_cluster(self) -> Operation:
        operation = Operation(
            operation_id=str(uuid.uuid4()),
            action="destroy",
            status="running",
            message="Destruction du cluster en cours",
            steps=["Destruction cluster demarree"],
            started_at=datetime.now(timezone.utc),
        )
        self._set_operation(operation)
        try:
            self._append_step(operation, "OpenTofu init")
            run_cmd([self.settings.iac_bin, "init", "-input=false"], cwd=self.terraform_dir)
            self._append_step(operation, "OpenTofu destroy")
            run_cmd([self.settings.iac_bin, "destroy", "-auto-approve"], cwd=self.terraform_dir)
            self._append_step(operation, "Nettoyage inventaire Ansible")
            self._write_empty_inventory()
            operation.status = "success"
            operation.message = "Cluster detruit avec succes"
            operation.steps.append("Destruction cluster terminee")
        except RuntimeError as exc:
            operation.status = "failed"
            operation.message = str(exc)
            operation.steps.append("Echec destruction cluster")
        operation.finished_at = datetime.now(timezone.utc)
        self._set_operation(operation)
        return operation

    def scale_to(self, target_nodes: int, colocate: bool | None = None) -> Operation:
        if target_nodes < self.settings.min_nodes or target_nodes > self.settings.max_nodes:
            raise ValueError(
                f"target_nodes doit etre entre {self.settings.min_nodes} et {self.settings.max_nodes}"
            )
        colocate_mode = (
            self.settings.colocate_controller_and_first_compute
            if colocate is None
            else colocate
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
            steps=["Scale demarre"],
            started_at=now,
        )
        self._set_operation(operation)

        try:
            self._append_step(operation, "OpenTofu init")
            run_cmd([self.settings.iac_bin, "init", "-input=false"], cwd=self.terraform_dir)
            self._append_step(operation, "OpenTofu apply")
            run_cmd(self._build_apply_command(target_nodes, colocate_mode), cwd=self.terraform_dir)
            self._append_step(operation, "Generation inventaire Ansible")
            self._sync_ansible_inventory()
            self._append_step(operation, "Execution playbook Ansible")
            run_cmd_stream(
                ["ansible-playbook", "-i", "inventory/generated_hosts.yml", "playbooks/site.yml"],
                cwd=self.ansible_dir,
                on_line=lambda line: self._append_log(operation, line),
            )
            operation.status = "success"
            operation.message = "Scale termine avec succes"
            operation.steps.append("Scale termine")
            self._last_scale_at = datetime.now(timezone.utc)
        except RuntimeError as exc:
            operation.status = "failed"
            operation.message = str(exc)
            operation.steps.append("Echec scale")
        finally:
            operation.finished_at = datetime.now(timezone.utc)
            self._set_operation(operation)
            self._lock.release()
        return operation
