import {
  defaultSpec,
  dependencyMap,
  policyControlSchema,
  sanitizeSpec,
  simulate
} from "./model.js";
import { WebGLBatchEngine } from "./webgl-engine.js";

const state = {
  spec: sanitizeSpec(defaultSpec()),
  result: null,
  scanResults: [],
  worker: null,
  runTimer: null,
  gpu: new WebGLBatchEngine()
};

const controls = {
  autoRunToggle: document.querySelector("#autoRunToggle"),
  runButton: document.querySelector("#runButton"),
  scanButton: document.querySelector("#scanButton"),
  loadPresetButton: document.querySelector("#loadPresetButton"),
  nodeList: document.querySelector("#nodeList"),
  policyList: document.querySelector("#policyList"),
  agentCountInput: document.querySelector("#agentCountInput"),
  agentCountValue: document.querySelector("#agentCountValue"),
  timeHorizonInput: document.querySelector("#timeHorizonInput"),
  timeHorizonValue: document.querySelector("#timeHorizonValue"),
  dtInput: document.querySelector("#dtInput"),
  dtValue: document.querySelector("#dtValue"),
  alphaInput: document.querySelector("#alphaInput"),
  alphaValue: document.querySelector("#alphaValue"),
  samplingModeSelect: document.querySelector("#samplingModeSelect"),
  seedInput: document.querySelector("#seedInput"),
  wTildeSelect: document.querySelector("#wTildeSelect"),
  uBarSelect: document.querySelector("#uBarSelect"),
  activePolicySelect: document.querySelector("#activePolicySelect"),
  activeRegulationInput: document.querySelector("#activeRegulationInput"),
  activeRegulationValue: document.querySelector("#activeRegulationValue"),
  summaryCards: document.querySelector("#summaryCards"),
  trajectoryCanvas: document.querySelector("#trajectoryCanvas"),
  incomeCanvas: document.querySelector("#incomeCanvas"),
  wTildeCanvas: document.querySelector("#wTildeCanvas"),
  uBarCanvas: document.querySelector("#uBarCanvas"),
  scanCanvas: document.querySelector("#scanCanvas"),
  graphSvg: document.querySelector("#graphSvg"),
  graphStatus: document.querySelector("#graphStatus"),
  scanStatus: document.querySelector("#scanStatus"),
  addNodeButton: document.querySelector("#addNodeButton")
};

const nodeTemplate = document.querySelector("#nodeCardTemplate");
const policyTemplate = document.querySelector("#policyTemplate");
const policySchema = policyControlSchema();

function scheduleRun() {
  if (!controls.autoRunToggle.checked) return;
  clearTimeout(state.runTimer);
  state.runTimer = setTimeout(runModel, 140);
}

function readGlobalControls() {
  state.spec.N = Number(controls.agentCountInput.value);
  state.spec.tEnd = Number(controls.timeHorizonInput.value);
  state.spec.dt = Number(controls.dtInput.value);
  state.spec.alpha = Number(controls.alphaInput.value);
  state.spec.samplingMode = controls.samplingModeSelect.value;
  state.spec.seed = Number(controls.seedInput.value || 1);
  state.spec.outputs.wTilde = controls.wTildeSelect.value;
  state.spec.outputs.uBar = controls.uBarSelect.value;
  state.spec.activePolicyIndex = Number(controls.activePolicySelect.value || 0);
  state.spec.activeRegulation = Number(controls.activeRegulationInput.value || 0);
}

function syncGlobalControls() {
  controls.agentCountInput.value = state.spec.N;
  controls.agentCountValue.textContent = state.spec.N;
  controls.timeHorizonInput.value = state.spec.tEnd;
  controls.timeHorizonValue.textContent = state.spec.tEnd;
  controls.dtInput.value = state.spec.dt;
  controls.dtValue.textContent = Number(state.spec.dt).toFixed(2);
  controls.alphaInput.value = state.spec.alpha;
  controls.alphaValue.textContent = Number(state.spec.alpha).toFixed(2);
  controls.samplingModeSelect.value = state.spec.samplingMode;
  controls.seedInput.value = state.spec.seed;
  controls.activeRegulationInput.value = state.spec.activeRegulation;
  controls.activeRegulationValue.textContent = Number(state.spec.activeRegulation).toFixed(2);
}

function updateSliderOutputs() {
  controls.agentCountValue.textContent = controls.agentCountInput.value;
  controls.timeHorizonValue.textContent = controls.timeHorizonInput.value;
  controls.dtValue.textContent = Number(controls.dtInput.value).toFixed(2);
  controls.alphaValue.textContent = Number(controls.alphaInput.value).toFixed(2);
  controls.activeRegulationValue.textContent = Number(controls.activeRegulationInput.value).toFixed(2);
}

function renderOutputSelectors() {
  const ids = state.spec.nodes.map((node) => node.id);
  for (const select of [controls.wTildeSelect, controls.uBarSelect]) {
    select.innerHTML = "";
    for (const id of ids) {
      const option = document.createElement("option");
      option.value = id;
      option.textContent = id;
      select.append(option);
    }
  }
  controls.wTildeSelect.value = state.spec.outputs.wTilde;
  controls.uBarSelect.value = state.spec.outputs.uBar;
}

function renderActivePolicySelect() {
  controls.activePolicySelect.innerHTML = "";
  state.spec.policies.forEach((policy, index) => {
    const option = document.createElement("option");
    option.value = String(index);
    option.textContent = policy.label;
    controls.activePolicySelect.append(option);
  });
  controls.activePolicySelect.value = String(state.spec.activePolicyIndex || 0);
}

function renderNodeCards() {
  controls.nodeList.innerHTML = "";
  for (const node of state.spec.nodes) {
    const fragment = nodeTemplate.content.cloneNode(true);
    const card = fragment.querySelector(".node-card");
    const labelInput = fragment.querySelector(".node-label-input");
    const idInput = fragment.querySelector(".node-id-input");
    const distributionSelect = fragment.querySelector(".node-distribution-select");
    const meanInput = fragment.querySelector(".node-mean-input");
    const sigmaInput = fragment.querySelector(".node-sigma-input");
    const minInput = fragment.querySelector(".node-min-input");
    const maxInput = fragment.querySelector(".node-max-input");
    const expressionInput = fragment.querySelector(".node-expression-input");
    const normalizeInput = fragment.querySelector(".node-normalize-input");
    const removeButton = fragment.querySelector(".remove-node-button");

    labelInput.value = node.label;
    idInput.value = node.id;
    distributionSelect.value = node.distribution;
    meanInput.value = node.mean ?? "";
    sigmaInput.value = node.sigma ?? "";
    minInput.value = node.min ?? "";
    maxInput.value = node.max ?? "";
    expressionInput.value = node.expression || "";
    normalizeInput.checked = !!node.normalize;

    const updateNode = () => {
      node.label = labelInput.value;
      node.id = idInput.value;
      node.distribution = distributionSelect.value;
      node.mean = numberOrNull(meanInput.value);
      node.sigma = numberOrNull(sigmaInput.value);
      node.min = numberOrNull(minInput.value);
      node.max = numberOrNull(maxInput.value);
      node.expression = expressionInput.value;
      node.normalize = normalizeInput.checked;
      state.spec = sanitizeSpec(state.spec);
      renderOutputSelectors();
      renderGraph();
      scheduleRun();
    };

    for (const input of [labelInput, idInput, distributionSelect, meanInput, sigmaInput, minInput, maxInput, expressionInput, normalizeInput]) {
      input.addEventListener("input", updateNode);
      input.addEventListener("change", updateNode);
    }

    removeButton.addEventListener("click", () => {
      state.spec.nodes = state.spec.nodes.filter((item) => item !== node);
      if (!state.spec.nodes.find((item) => item.id === state.spec.outputs.wTilde)) {
        state.spec.outputs.wTilde = state.spec.nodes[0]?.id || "";
      }
      if (!state.spec.nodes.find((item) => item.id === state.spec.outputs.uBar)) {
        state.spec.outputs.uBar = state.spec.nodes[0]?.id || "";
      }
      renderAll();
      scheduleRun();
    });

    controls.nodeList.append(card);
  }
}

function renderPolicies() {
  controls.policyList.innerHTML = "";
  for (const policy of state.spec.policies) {
    const fragment = policyTemplate.content.cloneNode(true);
    const enabledInput = fragment.querySelector(".policy-enabled-input");
    const nameNode = fragment.querySelector(".policy-name");
    const body = fragment.querySelector(".policy-body");
    enabledInput.checked = !!policy.enabled;
    nameNode.textContent = policy.label;

    enabledInput.addEventListener("change", () => {
      policy.enabled = enabledInput.checked;
      scheduleRun();
    });

    for (const field of policySchema[policy.type] || []) {
      const label = document.createElement("label");
      const span = document.createElement("span");
      span.textContent = field.label;
      label.append(span);

      let input;
      if (field.type === "select") {
        input = document.createElement("select");
        for (const optionValue of field.options) {
          const option = document.createElement("option");
          option.value = optionValue;
          option.textContent = optionValue;
          input.append(option);
        }
      } else {
        input = document.createElement("input");
        input.type = "range";
        input.min = field.min;
        input.max = field.max;
        input.step = field.step;
        const output = document.createElement("output");
        output.textContent = policy[field.key] ?? field.min;
        label.append(output);
        input.addEventListener("input", () => {
          output.textContent = input.value;
        });
      }

      input.value = policy[field.key] ?? field.options?.[0] ?? field.min;
      input.addEventListener("input", () => {
        policy[field.key] = input.type === "range" ? Number(input.value) : input.value;
        scheduleRun();
      });
      label.append(input);
      body.append(label);
    }

    controls.policyList.append(fragment);
  }
}

function renderGraph() {
  const deps = dependencyMap(state.spec);
  const svg = controls.graphSvg;
  svg.innerHTML = "";
  const width = 960;
  const height = 300;
  const ids = state.spec.nodes.map((node) => node.id);
  const columns = ids.length;
  const positions = new Map();

  ids.forEach((id, index) => {
    positions.set(id, {
      x: 90 + (index * (width - 180)) / Math.max(1, columns - 1),
      y: 140 + Math.sin(index / Math.max(1, columns - 1) * Math.PI) * 40
    });
  });

  for (const [target, sources] of deps.entries()) {
    for (const source of sources) {
      const start = positions.get(source);
      const end = positions.get(target);
      if (!start || !end) continue;
      const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
      const c1x = start.x + (end.x - start.x) * 0.45;
      const c2x = start.x + (end.x - start.x) * 0.55;
      path.setAttribute("d", `M ${start.x} ${start.y} C ${c1x} ${start.y - 35}, ${c2x} ${end.y - 35}, ${end.x} ${end.y}`);
      path.setAttribute("class", "graph-edge");
      svg.append(path);
    }
  }

  for (const node of state.spec.nodes) {
    const { x, y } = positions.get(node.id);
    const rect = document.createElementNS("http://www.w3.org/2000/svg", "rect");
    rect.setAttribute("x", x - 62);
    rect.setAttribute("y", y - 26);
    rect.setAttribute("width", 124);
    rect.setAttribute("height", 52);
    rect.setAttribute("rx", 20);
    rect.setAttribute("class", `graph-node${(node.id === state.spec.outputs.wTilde || node.id === state.spec.outputs.uBar) ? " active" : ""}`);
    svg.append(rect);

    const label = document.createElementNS("http://www.w3.org/2000/svg", "text");
    label.setAttribute("x", x);
    label.setAttribute("y", y - 4);
    label.setAttribute("text-anchor", "middle");
    label.setAttribute("class", "graph-label");
    label.textContent = node.label;
    svg.append(label);

    const idLabel = document.createElementNS("http://www.w3.org/2000/svg", "text");
    idLabel.setAttribute("x", x);
    idLabel.setAttribute("y", y + 14);
    idLabel.setAttribute("text-anchor", "middle");
    idLabel.setAttribute("fill", "#756558");
    idLabel.setAttribute("font-size", "11");
    idLabel.textContent = node.id;
    svg.append(idLabel);
  }
  controls.graphStatus.textContent = `${state.spec.nodes.length} variables · ${state.gpu.describe()}`;
}

function renderSummary() {
  controls.summaryCards.innerHTML = "";
  if (!state.result) return;
  const fields = [
    ["Resource Revenue", formatNumber(state.result.summary.resourceRevenue)],
    ["Total Revenue", formatNumber(state.result.summary.totalRevenue)],
    ["Gini", state.result.summary.gini.toFixed(3)],
    ["Ecology", state.result.summary.ecology.toFixed(3)],
    ["Participation", state.result.summary.participation.toFixed(3)],
    ["Price", state.result.summary.price.toFixed(3)]
  ];
  for (const [label, value] of fields) {
    const div = document.createElement("div");
    div.className = "summary-item";
    div.innerHTML = `<span>${label}</span><strong>${value}</strong>`;
    controls.summaryCards.append(div);
  }
}

function drawLineChart(canvas, series, { yLabel = "", palette = ["#284b63", "#b1452d", "#116466", "#844685"] } = {}) {
  const ctx = canvas.getContext("2d");
  const dpr = window.devicePixelRatio || 1;
  const width = canvas.width;
  const height = canvas.height;
  canvas.width = width * dpr;
  canvas.height = height * dpr;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, width, height);
  ctx.fillStyle = "#fffdfa";
  ctx.fillRect(0, 0, width, height);
  const margin = { top: 20, right: 18, bottom: 28, left: 44 };
  const plotWidth = width - margin.left - margin.right;
  const plotHeight = height - margin.top - margin.bottom;
  const xs = series.flatMap((entry) => entry.x);
  const ys = series.flatMap((entry) => entry.y);
  const xMin = Math.min(...xs);
  const xMax = Math.max(...xs);
  const yMin = Math.min(...ys);
  const yMax = Math.max(...ys);
  const px = (x) => margin.left + ((x - xMin) / Math.max(1e-6, xMax - xMin)) * plotWidth;
  const py = (y) => margin.top + plotHeight - ((y - yMin) / Math.max(1e-6, yMax - yMin)) * plotHeight;

  ctx.strokeStyle = "rgba(117, 101, 88, 0.2)";
  ctx.lineWidth = 1;
  for (let i = 0; i < 5; i += 1) {
    const y = margin.top + (plotHeight * i) / 4;
    ctx.beginPath();
    ctx.moveTo(margin.left, y);
    ctx.lineTo(width - margin.right, y);
    ctx.stroke();
  }

  series.forEach((entry, index) => {
    ctx.strokeStyle = entry.color || palette[index % palette.length];
    ctx.lineWidth = 2.4;
    ctx.beginPath();
    entry.x.forEach((x, i) => {
      if (i === 0) ctx.moveTo(px(x), py(entry.y[i]));
      else ctx.lineTo(px(x), py(entry.y[i]));
    });
    ctx.stroke();
  });

  ctx.fillStyle = "#756558";
  ctx.font = "12px Avenir Next";
  ctx.fillText(yLabel, 10, 16);
}

function drawHistogram(canvas, values, color) {
  const bins = 18;
  const min = Math.min(...values);
  const max = Math.max(...values);
  const counts = new Array(bins).fill(0);
  for (const value of values) {
    const index = Math.min(bins - 1, Math.floor(((value - min) / Math.max(1e-6, max - min)) * bins));
    counts[index] += 1;
  }
  const ctx = canvas.getContext("2d");
  const width = canvas.width;
  const height = canvas.height;
  ctx.clearRect(0, 0, width, height);
  ctx.fillStyle = "#fffdfa";
  ctx.fillRect(0, 0, width, height);
  const maxCount = Math.max(...counts, 1);
  const pad = 18;
  const barWidth = (width - pad * 2) / bins;
  counts.forEach((count, index) => {
    const h = ((height - 36) * count) / maxCount;
    ctx.fillStyle = color;
    ctx.fillRect(pad + index * barWidth, height - 20 - h, barWidth - 4, h);
  });
}

function renderCharts() {
  if (!state.result) return;
  drawLineChart(controls.trajectoryCanvas, [
    { x: state.result.trajectory.t, y: state.result.trajectory.y, color: "#284b63" },
    { x: state.result.trajectory.t, y: state.result.trajectory.participation, color: "#b1452d" }
  ], { yLabel: "Resource / Participation" });

  drawHistogram(controls.wTildeCanvas, state.result.distributions.wTilde, "#b1452d");
  drawHistogram(controls.uBarCanvas, state.result.distributions.uBar, "#116466");

  const totals = state.result.incomes.total;
  const resource = state.result.incomes.resource;
  const trade = state.result.incomes.trade;
  const indices = [...totals.keys()].sort((a, b) => totals[b] - totals[a]);
  drawLineChart(controls.incomeCanvas, [
    { x: indices, y: indices.map((index) => totals[index]), color: "#284b63" },
    { x: indices, y: indices.map((index) => resource[index]), color: "#116466" },
    { x: indices, y: indices.map((index) => trade[index]), color: "#b1452d" }
  ], { yLabel: "Income" });
}

function renderScan() {
  const canvas = controls.scanCanvas;
  if (!state.scanResults.length) {
    const ctx = canvas.getContext("2d");
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = "#fffdfa";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = "#756558";
    ctx.font = "16px Avenir Next";
    ctx.fillText("Run a policy scan to compare regulation curves.", 24, 40);
    return;
  }
  drawLineChart(
    canvas,
    state.scanResults.map((scan, index) => ({
      x: scan.r,
      y: scan.totalRevenue,
      color: ["#284b63", "#b1452d", "#116466", "#844685", "#5d8a66"][index % 5]
    })),
    { yLabel: "Total Revenue" }
  );
}

function runModel() {
  try {
    readGlobalControls();
    state.spec = sanitizeSpec(state.spec);
    const selectedPolicy = state.spec.policies[state.spec.activePolicyIndex] || state.spec.policies[0];
    state.result = simulate(state.spec, { ...selectedPolicy, regulation: state.spec.activeRegulation });
    renderSummary();
    renderCharts();
    renderGraph();
  } catch (error) {
    controls.graphStatus.textContent = error.message;
    console.error(error);
  }
}

function runScan() {
  readGlobalControls();
  if (state.worker) {
    state.worker.terminate();
  }
  state.scanResults = [];
  renderScan();
  controls.scanStatus.textContent = "Scanning…";
  state.worker = new Worker("./policy-scan-worker.js", { type: "module" });
  state.worker.onmessage = (event) => {
    if (event.data.ok) {
      state.scanResults = event.data.results;
      controls.scanStatus.textContent = `${state.scanResults.length} policies`;
      renderScan();
    } else {
      controls.scanStatus.textContent = event.data.error;
    }
  };
  state.worker.postMessage({ spec: state.spec, resolution: 28 });
}

function renderAll() {
  syncGlobalControls();
  updateSliderOutputs();
  renderOutputSelectors();
  renderActivePolicySelect();
  renderNodeCards();
  renderPolicies();
  renderGraph();
  runModel();
  renderScan();
}

function formatNumber(value) {
  return Number(value).toFixed(Math.abs(value) >= 100 ? 1 : 3);
}

function numberOrNull(value) {
  return value === "" ? null : Number(value);
}

controls.runButton.addEventListener("click", runModel);
controls.scanButton.addEventListener("click", runScan);
controls.loadPresetButton.addEventListener("click", () => {
  state.spec = sanitizeSpec(defaultSpec());
  renderAll();
});
controls.addNodeButton.addEventListener("click", () => {
  state.spec.nodes.push({
    id: `node_${state.spec.nodes.length + 1}`,
    label: `Node ${state.spec.nodes.length + 1}`,
    distribution: "Uniform",
    min: 0,
    max: 1,
    expression: "",
    normalize: false
  });
  renderAll();
});

for (const input of [
  controls.agentCountInput,
  controls.timeHorizonInput,
  controls.dtInput,
  controls.alphaInput,
  controls.samplingModeSelect,
  controls.seedInput,
  controls.wTildeSelect,
  controls.uBarSelect,
  controls.activePolicySelect,
  controls.activeRegulationInput
]) {
  input.addEventListener("input", () => {
    updateSliderOutputs();
    scheduleRun();
  });
  input.addEventListener("change", () => {
    updateSliderOutputs();
    scheduleRun();
  });
}

renderAll();
