const API_BASE = "http://127.0.0.1:8000";

const tokenInput = document.getElementById("token");
const refreshBtn = document.getElementById("refreshBtn");
const clusterState = document.getElementById("clusterState");
const targetNodesInput = document.getElementById("targetNodes");
const scaleBtn = document.getElementById("scaleBtn");
const scaleResponse = document.getElementById("scaleResponse");

function authHeaders() {
  return {
    "Content-Type": "application/json",
    Authorization: `Bearer ${tokenInput.value.trim()}`,
  };
}

async function refreshState() {
  clusterState.textContent = "Chargement...";
  try {
    const resp = await fetch(`${API_BASE}/cluster/state`, {
      headers: authHeaders(),
    });
    const data = await resp.json();
    clusterState.textContent = JSON.stringify(data, null, 2);
  } catch (err) {
    clusterState.textContent = `Erreur: ${err.message}`;
  }
}

async function scaleCluster() {
  scaleResponse.textContent = "Operation en cours...";
  try {
    const targetNodes = Number(targetNodesInput.value);
    const resp = await fetch(`${API_BASE}/cluster/scale`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ target_nodes: targetNodes }),
    });
    const data = await resp.json();
    scaleResponse.textContent = JSON.stringify(data, null, 2);
    await refreshState();
  } catch (err) {
    scaleResponse.textContent = `Erreur: ${err.message}`;
  }
}

refreshBtn.addEventListener("click", refreshState);
scaleBtn.addEventListener("click", scaleCluster);
