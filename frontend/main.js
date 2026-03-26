const API_BASE = "http://127.0.0.1:8000";

const refreshBtn = document.getElementById("refreshBtn");
const clusterState = document.getElementById("clusterState");
const createTargetNodesInput = document.getElementById("createTargetNodes");
const colocateFirstComputeInput = document.getElementById("colocateFirstCompute");
const createBtn = document.getElementById("createBtn");
const destroyBtn = document.getElementById("destroyBtn");
const clusterLifecycleResponse = document.getElementById("clusterLifecycleResponse");

function authHeaders() {
  return {
    "Content-Type": "application/json",
  };
}

function formatOperation(data) {
  if (!data || typeof data !== "object") {
    return JSON.stringify(data, null, 2);
  }
  const view = {
    operation_id: data.operation_id,
    action: data.action,
    status: data.status,
    message: data.message,
    steps: data.steps || [],
    logs_tail: (data.logs || []).slice(-40),
    started_at: data.started_at,
    finished_at: data.finished_at,
  };
  return JSON.stringify(view, null, 2);
}

async function fetchClusterState() {
  const resp = await fetch(`${API_BASE}/cluster/state`, {
    headers: authHeaders(),
  });
  if (!resp.ok) {
    throw new Error(`HTTP ${resp.status}: ${await resp.text()}`);
  }
  return resp.json();
}

async function refreshState() {
  clusterState.textContent = "Chargement...";
  try {
    const data = await fetchClusterState();
    clusterState.textContent = JSON.stringify(data, null, 2);
  } catch (err) {
    clusterState.textContent = `Erreur: ${err.message}`;
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function streamOperationProgress(actionName, outputEl, finalPromise) {
  outputEl.textContent = `${actionName} en cours...`;
  while (true) {
    const result = await Promise.race([
      finalPromise.then((value) => ({ done: true, value })),
      sleep(1000).then(() => ({ done: false })),
    ]);

    try {
      const state = await fetchClusterState();
      clusterState.textContent = JSON.stringify(state, null, 2);
      if (state.last_operation) {
        outputEl.textContent = formatOperation(state.last_operation);
      }
    } catch (err) {
      outputEl.textContent = `Progression indisponible: ${err.message}`;
    }

    if (result.done) {
      return result.value;
    }
  }
}

async function createCluster() {
  const targetNodes = Number(createTargetNodesInput.value);
  const requestPromise = fetch(`${API_BASE}/cluster/create`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify({
      target_nodes: targetNodes,
      colocate_controller_and_first_compute: colocateFirstComputeInput.checked,
    }),
  });

  try {
    const resp = await streamOperationProgress(
      "Creation du cluster",
      clusterLifecycleResponse,
      requestPromise
    );
    if (!resp.ok) {
      const text = await resp.text();
      clusterLifecycleResponse.textContent = `Erreur HTTP ${resp.status}: ${text}`;
      return;
    }
    const data = await resp.json();
    clusterLifecycleResponse.textContent = formatOperation(data);
    await refreshState();
  } catch (err) {
    clusterLifecycleResponse.textContent = `Erreur: ${err.message}`;
  }
}

async function destroyCluster() {
  const requestPromise = fetch(`${API_BASE}/cluster/destroy`, {
    method: "POST",
    headers: authHeaders(),
  });

  try {
    const resp = await streamOperationProgress(
      "Destruction du cluster",
      clusterLifecycleResponse,
      requestPromise
    );
    if (!resp.ok) {
      const text = await resp.text();
      clusterLifecycleResponse.textContent = `Erreur HTTP ${resp.status}: ${text}`;
      return;
    }
    const data = await resp.json();
    clusterLifecycleResponse.textContent = formatOperation(data);
    await refreshState();
  } catch (err) {
    clusterLifecycleResponse.textContent = `Erreur: ${err.message}`;
  }
}

refreshBtn.addEventListener("click", refreshState);
createBtn.addEventListener("click", createCluster);
destroyBtn.addEventListener("click", destroyCluster);
