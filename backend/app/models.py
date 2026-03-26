from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


OperationStatus = Literal["pending", "running", "success", "failed"]


class ScaleRequest(BaseModel):
    target_nodes: int = Field(ge=1, le=999)


class Operation(BaseModel):
    operation_id: str
    action: str
    target_nodes: int | None = None
    status: OperationStatus
    message: str = ""
    started_at: datetime
    finished_at: datetime | None = None


class ClusterState(BaseModel):
    desired_nodes: int
    current_nodes: int
    controller: dict
    compute_nodes: list[dict]
    last_operation: Operation | None = None


class JobInfo(BaseModel):
    id: str
    state: str
    name: str
