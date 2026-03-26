const API_BASE = "http://127.0.0.1:8000";
const REFRESH_MS = 2000;

const refreshBtn = document.getElementById("refreshBtn");
const createTargetNodesInput = document.getElementById("createTargetNodes");
const colocateFirstComputeInput = document.getElementById("colocateFirstCompute");
const createBtn = document.getElementById("createBtn");
const destroyBtn = document.getElementById("destroyBtn");
const statusBadge = document.getElementById("statusBadge");
const nodesSummary = document.getElementById("nodesSummary");
const controllerSummary = document.getElementById("controllerSummary");
const operationSummary = document.getElementById("operationSummary");
const refreshSummary = document.getElementById("refreshSummary");
const ipsSummary = document.getElementById("ipsSummary");
const logsWindow = document.getElementById("logsWindow");
let inFlightAction = false;

function authHeaders() {
  return {
    "Content-Type": "application/json",
  };
}

function renderSummary(state) {
  const op = state.last_operation || null;
  const current = state.current_nodes ?? 0;
  const desired = state.desired_nodes ?? 0;
  const ctrlName = state.controller?.name || "-";
  const ctrlIp = state.controller?.ipv4 || "-";
  const computeCount = (state.compute_nodes || []).length;

  nodesSummary.textContent = `${current} actifs (desired: ${desired}, compute: ${computeCount})`;
  controllerSummary.textContent = `${ctrlName} (${ctrlIp})`;
  operationSummary.textContent = op
    ? `${op.action} - ${op.status} - ${op.message || ""}`.trim()
    : "aucune";

  const ips = [];
  if (ctrlIp !== "-") {
    ips.push(`controller=${ctrlIp}`);
  }
  for (const node of state.compute_nodes || []) {
    ips.push(`${node.name}=${node.ipv4}`);
  }
  ipsSummary.textContent = ips.length ? ips.join(" | ") : "-";

  const changing = op && op.status === "running";
  statusBadge.textContent = changing ? "changement en cours" : "stable";
  statusBadge.style.background = changing ? "#fff3cd" : "#e6ffed";
  statusBadge.style.borderColor = changing ? "#f0c36d" : "#5a9f5a";
}

function renderLogs(state) {
  const op = state.last_operation || null;
  if (!op) {
    logsWindow.textContent = "Aucune operation enregistree.";
    return;
  }
  const lines = [];
  lines.push(`[${op.status}] ${op.action} (${op.operation_id})`);
  if (op.steps?.length) {
    lines.push("");
    lines.push("Steps:");
    for (const s of op.steps) {
      lines.push(`- ${s}`);
    }
  }
  const logs = op.logs || [];
  if (logs.length) {
    lines.push("");
    lines.push("Logs:");
    for (const line of logs.slice(-120)) {
      lines.push(line);
    }
  }
  logsWindow.textContent = lines.join("\n");
  logsWindow.scrollTop = logsWindow.scrollHeight;
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
  try {
    const data = await fetchClusterState();
    renderSummary(data);
    renderLogs(data);
  } catch (err) {
    logsWindow.textContent = `Erreur: ${err.message}`;
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
      renderSummary(state);
      renderLogs(state);
    } catch (err) {
      outputEl.textContent = `Progression indisponible: ${err.message}`;
    }

    if (result.done) {
      return result.value;
    }
  }
}

async function createCluster() {
  if (inFlightAction) return;
  inFlightAction = true;
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
      logsWindow,
      requestPromise
    );
    if (!resp.ok) {
      const text = await resp.text();
      logsWindow.textContent = `Erreur HTTP ${resp.status}: ${text}`;
      return;
    }
    await resp.json();
    await refreshState();
  } catch (err) {
    logsWindow.textContent = `Erreur: ${err.message}`;
  } finally {
    inFlightAction = false;
  }
}

async function destroyCluster() {
  if (inFlightAction) return;
  inFlightAction = true;
  const requestPromise = fetch(`${API_BASE}/cluster/destroy`, {
    method: "POST",
    headers: authHeaders(),
  });

  try {
    const resp = await streamOperationProgress(
      "Destruction du cluster",
      logsWindow,
      requestPromise
    );
    if (!resp.ok) {
      const text = await resp.text();
      logsWindow.textContent = `Erreur HTTP ${resp.status}: ${text}`;
      return;
    }
    await resp.json();
    await refreshState();
  } catch (err) {
    logsWindow.textContent = `Erreur: ${err.message}`;
  } finally {
    inFlightAction = false;
  }
}

refreshSummary.textContent = `toutes les ${REFRESH_MS / 1000}s`;
refreshBtn.addEventListener("click", refreshState);
createBtn.addEventListener("click", createCluster);
destroyBtn.addEventListener("click", destroyCluster);
setInterval(() => {
  if (!inFlightAction) {
    refreshState();
  }
}, REFRESH_MS);
refreshState();
