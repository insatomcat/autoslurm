from datetime import datetime, timedelta, timezone

from app.config import Settings
from app.services.cluster_service import ClusterService


class AutoscalerService:
    def __init__(self, settings: Settings, cluster_service: ClusterService) -> None:
        self.settings = settings
        self.cluster_service = cluster_service
        self._last_action_at: datetime | None = None

    def evaluate(self) -> dict:
        now = datetime.now(timezone.utc)
        if self._last_action_at and now - self._last_action_at < timedelta(
            seconds=self.settings.cooldown_seconds
        ):
            return {"action": "none", "reason": "cooldown"}

        state = self.cluster_service.get_state()
        jobs = self.cluster_service.get_jobs()

        pending_jobs = len([j for j in jobs if j.state in {"PD", "CF"}])
        idle_nodes = max(state.current_nodes - max(len(jobs), 0), 0)

        if pending_jobs >= self.settings.pending_jobs_threshold:
            target = min(state.current_nodes + 1, self.settings.max_nodes)
            if target != state.current_nodes:
                self.cluster_service.scale_to(target)
                self._last_action_at = now
                return {"action": "scale_up", "target_nodes": target}

        if idle_nodes >= self.settings.idle_nodes_threshold:
            target = max(state.current_nodes - 1, self.settings.min_nodes)
            if target != state.current_nodes:
                self.cluster_service.scale_to(target)
                self._last_action_at = now
                return {"action": "scale_down", "target_nodes": target}

        return {"action": "none", "reason": "threshold_not_reached"}
