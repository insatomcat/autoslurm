from fastapi import Depends, FastAPI, Header, HTTPException

from app.config import Settings
from app.models import ClusterState, JobInfo, Operation, ScaleRequest
from app.services.autoscaler import AutoscalerService
from app.services.cluster_service import ClusterService

app = FastAPI(title="autoslurm-api", version="0.1.0")
settings = Settings()
cluster_service = ClusterService(settings)
autoscaler_service = AutoscalerService(settings, cluster_service)


def require_token(authorization: str = Header(default="")) -> None:
    if authorization != f"Bearer {settings.api_token}":
        raise HTTPException(status_code=401, detail="Unauthorized")


@app.get("/health")
def health() -> dict:
    return {"ok": True}


@app.get("/cluster/state", response_model=ClusterState, dependencies=[Depends(require_token)])
def cluster_state() -> ClusterState:
    return cluster_service.get_state()


@app.get("/cluster/jobs", response_model=list[JobInfo], dependencies=[Depends(require_token)])
def cluster_jobs() -> list[JobInfo]:
    return cluster_service.get_jobs()


@app.post("/cluster/reconcile", response_model=Operation, dependencies=[Depends(require_token)])
def reconcile() -> Operation:
    return cluster_service.reconcile()


@app.post("/cluster/scale", response_model=Operation, dependencies=[Depends(require_token)])
def scale(req: ScaleRequest) -> Operation:
    try:
        return cluster_service.scale_to(req.target_nodes)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/autoscaler/evaluate", dependencies=[Depends(require_token)])
def evaluate_autoscaler() -> dict:
    try:
        return autoscaler_service.evaluate()
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
