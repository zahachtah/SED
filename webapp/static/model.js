const TWO_PI = Math.PI * 2;

export function defaultSpec() {
  return {
    N: 96,
    tEnd: 800,
    dt: 0.08,
    alpha: 0.1,
    activePolicyIndex: 0,
    activeRegulation: 0.3,
    samplingMode: "quantiles",
    seed: 42,
    outputs: {
      wTilde: "w_tilde",
      uBar: "u_bar"
    },
    nodes: [
      { id: "q", label: "Access", distribution: "Uniform", min: 1, max: 1, normalize: true, expression: "" },
      { id: "w", label: "Base Incentive", distribution: "Uniform", min: 0.2, max: 0.45, normalize: false, expression: "" },
      { id: "opportunity", label: "Alt. Income", distribution: "LogNormal", min: 0.08, max: 1.4, normalize: false, expression: "" },
      { id: "w_tilde", label: "w̃", distribution: "Uniform", min: 0.02, max: 0.15, normalize: false, expression: "q * w + opportunity * 0.25 + independent" },
      { id: "u_bar", label: "ū", distribution: "Uniform", min: 0.05, max: 0.2, normalize: false, expression: "clamp(q / (w_tilde + 0.1) + independent, 0.02, 2.0)" }
    ],
    policies: [
      { type: "OpenAccess", label: "Open Access", enabled: true },
      { type: "ExclusiveUseRights", label: "Exclusive Use Rights", enabled: true, selector: "top" },
      { type: "TradableUseRights", label: "Tradable Use Rights", enabled: true, target: "effort", marketRate: 0.05, buyerBias: 0.0 },
      { type: "ProtectedArea", label: "Protected Area", enabled: true, mobility: 0.3 },
      { type: "EconomicIncentives", label: "Economic Incentives", enabled: false, target: "cost", method: "multiplicative" }
    ]
  };
}

export function makeRng(seed = 1) {
  let state = (seed >>> 0) || 1;
  return () => {
    state ^= state << 13;
    state ^= state >>> 17;
    state ^= state << 5;
    return ((state >>> 0) / 4294967296);
  };
}

function sanitizeNodeId(id) {
  return String(id || "")
    .trim()
    .replace(/[^\w]/g, "_")
    .replace(/^(\d)/, "_$1");
}

export function dependencyMap(spec) {
  const nodeIds = new Set(spec.nodes.map((node) => sanitizeNodeId(node.id)));
  const map = new Map();
  for (const node of spec.nodes) {
    const expression = String(node.expression || "");
    const deps = [...expression.matchAll(/\b[a-zA-Z_]\w*\b/g)]
      .map((match) => match[0])
      .filter((token) => nodeIds.has(token) && token !== sanitizeNodeId(node.id));
    map.set(sanitizeNodeId(node.id), [...new Set(deps)]);
  }
  return map;
}

export function topoSort(spec) {
  const deps = dependencyMap(spec);
  const indegree = new Map();
  const outgoing = new Map();
  for (const node of spec.nodes) {
    const id = sanitizeNodeId(node.id);
    indegree.set(id, 0);
    outgoing.set(id, []);
  }
  for (const [nodeId, parents] of deps.entries()) {
    indegree.set(nodeId, parents.length);
    for (const parent of parents) {
      outgoing.get(parent).push(nodeId);
    }
  }
  const queue = [...indegree.entries()].filter(([, count]) => count === 0).map(([id]) => id);
  const order = [];
  while (queue.length) {
    const id = queue.shift();
    order.push(id);
    for (const child of outgoing.get(id) || []) {
      const next = indegree.get(child) - 1;
      indegree.set(child, next);
      if (next === 0) {
        queue.push(child);
      }
    }
  }
  if (order.length !== spec.nodes.length) {
    throw new Error("Dependency cycle detected.");
  }
  return order;
}

function normalQuantile(p) {
  const a = [-39.6968302866538, 220.946098424521, -275.928510446969, 138.357751867269, -30.6647980661472, 2.50662827745924];
  const b = [-54.4760987982241, 161.585836858041, -155.698979859887, 66.8013118877197, -13.2806815528857];
  const c = [-0.00778489400243029, -0.322396458041136, -2.40075827716184, -2.54973253934373, 4.37466414146497, 2.93816398269878];
  const d = [0.00778469570904146, 0.32246712907004, 2.445134137143, 3.75440866190742];
  const plow = 0.02425;
  const phigh = 1 - plow;
  if (p < plow) {
    const q = Math.sqrt(-2 * Math.log(p));
    return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
      ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
  }
  if (p > phigh) {
    const q = Math.sqrt(-2 * Math.log(1 - p));
    return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
      ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
  }
  const q = p - 0.5;
  const r = q * q;
  return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q /
    (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1);
}

function clamp(value, lo, hi) {
  return Math.min(Math.max(value, lo), hi);
}

function gammaSample(shape, rng) {
  if (shape < 1) {
    return gammaSample(1 + shape, rng) * Math.pow(rng(), 1 / shape);
  }
  const d = shape - 1 / 3;
  const c = 1 / Math.sqrt(9 * d);
  for (;;) {
    let x;
    let v;
    do {
      x = normalQuantile(Math.max(1e-9, rng()));
      v = 1 + c * x;
    } while (v <= 0);
    v = v * v * v;
    const u = rng();
    if (u < 1 - 0.0331 * Math.pow(x, 4)) {
      return d * v;
    }
    if (Math.log(u) < 0.5 * x * x + d * (1 - v + Math.log(v))) {
      return d * v;
    }
  }
}

function betaSample(alpha, beta, rng) {
  const x = gammaSample(alpha, rng);
  const y = gammaSample(beta, rng);
  return x / (x + y);
}

function sampleDistribution(node, N, mode, rng) {
  const distribution = node.distribution || "Uniform";
  const values = new Float32Array(N);
  const min = node.min ?? 0;
  const max = node.max ?? 1;
  const mean = node.mean ?? ((min + max) / 2);
  const sigma = Math.abs(node.sigma ?? Math.max(0.01, (max - min) / 4));

  for (let i = 0; i < N; i += 1) {
    const p = mode === "random" ? clamp(rng(), 1e-6, 1 - 1e-6) : (i + 1) / (N + 1);
    let value = 0;
    if (distribution === "Uniform") {
      value = min + (max - min) * p;
    } else if (distribution === "Normal") {
      value = mean + sigma * normalQuantile(p);
    } else if (distribution === "LogNormal") {
      if (node.min != null && node.max != null && node.min > 0 && node.max > node.min) {
        const zLo = normalQuantile(0.01);
        const zHi = normalQuantile(0.99);
        const sigmaLog = (Math.log(node.max) - Math.log(node.min)) / (zHi - zLo);
        const muLog = Math.log(node.min) - sigmaLog * zLo;
        value = Math.exp(muLog + sigmaLog * normalQuantile(p));
      } else {
        const sigmaLog = sigma;
        const muLog = Math.log(Math.max(mean, 1e-6)) - sigmaLog * sigmaLog / 2;
        value = Math.exp(muLog + sigmaLog * normalQuantile(p));
      }
    } else if (distribution === "Exponential") {
      const scale = Math.max(mean || sigma || 1, 1e-6);
      value = -scale * Math.log(1 - p);
    } else if (distribution === "Bernoulli") {
      const threshold = clamp(mean, 0, 1);
      value = p < threshold ? 1 : 0;
    } else if (distribution === "Beta") {
      const alpha = Math.max(node.alpha ?? 2, 1e-4);
      const beta = Math.max(node.beta ?? 2, 1e-4);
      value = mode === "random" ? betaSample(alpha, beta, rng) : clamp(alpha / (alpha + beta) + normalQuantile(p) * 0.05, 0, 1);
    }
    if (node.min != null && distribution !== "Bernoulli" && distribution !== "Uniform" && distribution !== "LogNormal") {
      value = Math.max(value, node.min);
    }
    if (node.max != null && distribution !== "Bernoulli" && distribution !== "Uniform" && distribution !== "LogNormal") {
      value = Math.min(value, node.max);
    }
    values[i] = value;
  }

  if (node.normalize) {
    let sum = 0;
    for (let i = 0; i < N; i += 1) sum += values[i];
    const inv = sum > 0 ? 1 / sum : 1;
    for (let i = 0; i < N; i += 1) values[i] *= inv;
  }
  return values;
}

function compileExpression(expression) {
  const body = expression && expression.trim() ? expression : "independent";
  return new Function(
    "scope",
    `const {independent, clamp, min, max, abs, sqrt, exp, log, sin, cos} = scope;
     with (scope) { return (${body}); }`
  );
}

function evaluateNode(node, context, N, mode, rng) {
  const base = sampleDistribution(node, N, mode, rng);
  const expression = (node.expression || "").trim();
  if (!expression) {
    return base;
  }
  const evaluator = compileExpression(expression);
  const values = new Float32Array(N);
  for (let i = 0; i < N; i += 1) {
    const scope = {
      independent: base[i],
      clamp,
      min: Math.min,
      max: Math.max,
      abs: Math.abs,
      sqrt: Math.sqrt,
      exp: Math.exp,
      log: Math.log,
      sin: Math.sin,
      cos: Math.cos
    };
    for (const [key, value] of Object.entries(context)) {
      scope[key] = ArrayBuffer.isView(value) ? value[i] : value;
    }
    values[i] = evaluator(scope);
  }
  if (node.normalize) {
    let sum = 0;
    for (let i = 0; i < N; i += 1) sum += values[i];
    const inv = sum > 0 ? 1 / sum : 1;
    for (let i = 0; i < N; i += 1) values[i] *= inv;
  }
  return values;
}

export function realizeScenario(spec) {
  const rng = makeRng(Number(spec.seed || 1));
  const N = Number(spec.N || 96);
  const mode = spec.samplingMode === "random" ? "random" : "quantiles";
  const nodesById = new Map(spec.nodes.map((node) => [sanitizeNodeId(node.id), node]));
  const order = topoSort(spec);
  const context = {
    K: 1.0
  };
  for (const id of order) {
    context[id] = evaluateNode(nodesById.get(id), context, N, mode, rng);
  }
  return context;
}

function mean(values) {
  let total = 0;
  for (let i = 0; i < values.length; i += 1) total += values[i];
  return total / values.length;
}

function sortIndices(values, reverse = false) {
  return [...values.keys()].sort((a, b) => reverse ? values[b] - values[a] : values[a] - values[b]);
}

function gini(values) {
  let total = 0;
  let sumAbs = 0;
  for (let i = 0; i < values.length; i += 1) {
    total += values[i];
    for (let j = 0; j < values.length; j += 1) {
      sumAbs += Math.abs(values[i] - values[j]);
    }
  }
  return total > 0 ? sumAbs / (2 * values.length * total) : 0;
}

function protectedAreaLimit(y, regulation, mobility, uBarValue) {
  if (regulation <= 0 || regulation >= 1) return uBarValue;
  const k = ((1 - regulation) / regulation) * mobility;
  const discriminant = Math.max(0, (1 - k) * (1 - k) + 4 * k * y);
  const yProtected = ((1 - k) + Math.sqrt(discriminant)) / 2;
  const spill = (regulation / Math.max(1e-6, 1 - regulation)) * mobility * (yProtected - y) / Math.max(y, 1e-6);
  return uBarValue / Math.max(1e-3, 1 + spill);
}

function buildPolicyState(policy, base) {
  const N = base.N;
  if (!policy || policy.type === "OpenAccess") {
    return {
      type: "OpenAccess",
      quota: new Float32Array(N).fill(1),
      selector: null,
      extraState: 0
    };
  }
  if (policy.type === "ExclusiveUseRights") {
    const source = policy.selectorSource === "opportunity" ? base.opportunity : base.wTilde;
    const ranked = sortIndices(source, policy.selector === "top");
    const excluded = new Float32Array(N);
    const count = Math.max(0, Math.min(N, Math.round((policy.regulation || 0) * N)));
    for (let i = 0; i < count; i += 1) excluded[ranked[i]] = 1;
    return { type: policy.type, quota: new Float32Array(N).fill(1), selector: excluded, extraState: 0 };
  }
  if (policy.type === "TradableUseRights") {
    const quota = new Float32Array(N).fill((1 - (policy.regulation || 0)) / N);
    return { type: policy.type, quota, selector: null, extraState: 0 };
  }
  return {
    type: policy.type,
    quota: new Float32Array(N).fill(1),
    selector: null,
    extraState: 0
  };
}

function deriveState(base, state, policy) {
  const { N, wTilde, uBar, opportunity } = base;
  const cost = new Float32Array(N);
  const limit = new Float32Array(N);
  const resourceFactor = new Float32Array(N).fill(1);
  const extraIncome = new Float32Array(N).fill(0);
  const regulation = policy.regulation || 0;
  const price = state.phi;
  for (let i = 0; i < N; i += 1) {
    cost[i] = wTilde[i];
    limit[i] = uBar[i];
  }

  if (policy.type === "ExclusiveUseRights") {
    for (let i = 0; i < N; i += 1) {
      cost[i] += policy.runtime.selector[i];
    }
  } else if (policy.type === "TradableUseRights") {
    for (let i = 0; i < N; i += 1) {
      cost[i] += price;
      if (policy.target === "yield") {
        extraIncome[i] = (policy.runtime.quota[i] - state.u[i] * state.y) * price;
      } else {
        extraIncome[i] = (policy.runtime.quota[i] - state.u[i]) * price;
      }
    }
  } else if (policy.type === "ProtectedArea") {
    for (let i = 0; i < N; i += 1) {
      cost[i] = wTilde[i] / Math.max(1e-3, 1 - regulation);
      limit[i] = protectedAreaLimit(state.y, regulation, policy.mobility || 0.3, uBar[i]);
      resourceFactor[i] = 1 - regulation;
    }
  } else if (policy.type === "EconomicIncentives") {
    const target = policy.target || "cost";
    const factor = policy.method === "taxation" ? (1 + regulation) : (1 - regulation);
    for (let i = 0; i < N; i += 1) {
      if (target === "cost") cost[i] *= factor;
      if (target === "limit") limit[i] *= Math.max(0.1, factor);
    }
  } else if (policy.type === "Development") {
    const phase = state.t / Math.max(1, base.tEnd);
    for (let i = 0; i < N; i += 1) {
      cost[i] += phase * regulation * (policy.gammaValue || 0.4);
      limit[i] += phase * regulation * (policy.muValue || 0.5) * 2 / N;
    }
  }

  return { cost, limit, resourceFactor, extraIncome, opportunity };
}

function stepDynamics(base, state, policy, dt) {
  const derived = deriveState(base, state, policy);
  const N = base.N;
  let sumU = 0;
  for (let i = 0; i < N; i += 1) sumU += state.u[i];
  const yDot = state.y * ((1 - state.y) - sumU);
  const dx = new Float32Array(N);
  for (let i = 0; i < N; i += 1) {
    dx[i] = base.alpha * (state.y - derived.cost[i]);
  }

  if (policy.type === "TradableUseRights") {
    let supply = 0;
    let demand = 0;
    const ids = [];
    for (let i = 0; i < N; i += 1) {
      const quotaGap = policy.target === "yield"
        ? policy.runtime.quota[i] - state.u[i] * state.y
        : policy.runtime.quota[i] - state.u[i];
      supply += Math.max(0, quotaGap);
      if (dx[i] > 0) {
        ids.push(i);
        demand += policy.target === "yield"
          ? Math.max(0, Math.min((derived.limit[i] - state.u[i]) * state.y, dx[i] * state.y))
          : Math.max(0, Math.min(derived.limit[i] - state.u[i], dx[i]));
      }
    }
    const phiDot = (policy.marketRate || 0.05) * (demand - supply);
    if (demand > supply && demand > 0) {
      for (const i of ids) {
        const desired = policy.target === "yield"
          ? Math.max(0, Math.min((derived.limit[i] - state.u[i]) * state.y, dx[i] * state.y))
          : Math.max(0, Math.min(derived.limit[i] - state.u[i], dx[i]));
        dx[i] = policy.target === "yield"
          ? (supply * desired / demand) / Math.max(state.y, 1e-6)
          : (supply * desired / demand);
      }
    }
    state.phi = Math.max(0, state.phi + dt * phiDot);
  }

  for (let i = 0; i < N; i += 1) {
    state.u[i] = clamp(state.u[i] + dt * dx[i], 0, Math.max(1e-6, derived.limit[i]));
  }
  state.y = Math.max(0, state.y + dt * yDot);
  state.t += dt;
  return derived;
}

export function simulate(spec, policyInput = { type: "OpenAccess", label: "Open Access", regulation: 0 }) {
  const context = realizeScenario(spec);
  const N = Number(spec.N || 96);
  const base = {
    N,
    alpha: Number(spec.alpha || 0.1),
    wTilde: context[sanitizeNodeId(spec.outputs.wTilde)],
    uBar: context[sanitizeNodeId(spec.outputs.uBar)],
    opportunity: context.opportunity || new Float32Array(N).fill(0),
    tEnd: Number(spec.tEnd || 800)
  };

  const policy = structuredClone(policyInput);
  policy.runtime = buildPolicyState(policy, base);

  const state = {
    u: new Float32Array(N).fill(policy.type === "TradableUseRights" ? 1e-5 : 0),
    y: 1,
    phi: 0,
    t: 0
  };

  const dt = Number(spec.dt || 0.08);
  const steps = Math.max(50, Math.round(base.tEnd / dt));
  const trajectory = {
    t: [],
    y: [],
    participation: []
  };
  let derived = deriveState(base, state, policy);
  for (let step = 0; step < steps; step += 1) {
    derived = stepDynamics(base, state, policy, dt);
    if (step % Math.max(1, Math.floor(steps / 240)) === 0 || step === steps - 1) {
      trajectory.t.push(state.t);
      trajectory.y.push(state.y);
      let participation = 0;
      for (let i = 0; i < N; i += 1) {
        participation += state.u[i] / Math.max(1e-6, derived.limit[i]);
      }
      trajectory.participation.push(participation / N);
    }
  }

  const resource = new Float32Array(N);
  const wages = new Float32Array(N);
  const trade = new Float32Array(N);
  const total = new Float32Array(N);
  for (let i = 0; i < N; i += 1) {
    resource[i] = state.u[i] * state.y * derived.resourceFactor[i];
    wages[i] = (derived.limit[i] - state.u[i]) * (
      policy.type === "ProtectedArea" || policy.type === "ExclusiveUseRights" || policy.type === "TradableUseRights"
        ? base.wTilde[i]
        : derived.cost[i]
    );
    trade[i] = derived.extraIncome[i];
    total[i] = resource[i] + wages[i] + trade[i];
  }

  return {
    base,
    context,
    policy,
    state: {
      u: Array.from(state.u),
      y: state.y,
      phi: state.phi
    },
    trajectory,
    distributions: {
      wTilde: Array.from(base.wTilde),
      uBar: Array.from(base.uBar)
    },
    incomes: {
      resource: Array.from(resource),
      wages: Array.from(wages),
      trade: Array.from(trade),
      total: Array.from(total)
    },
    summary: {
      resourceRevenue: sumArray(resource),
      totalRevenue: sumArray(total),
      gini: gini(total),
      ecology: state.y,
      participation: mean(trajectory.participation),
      price: state.phi
    }
  };
}

function sumArray(values) {
  let total = 0;
  for (let i = 0; i < values.length; i += 1) total += values[i];
  return total;
}

export function scanPolicySet(spec, options = {}) {
  const enabledPolicies = (spec.policies || []).filter((policy) => policy.enabled);
  const resolution = options.resolution || 24;
  return enabledPolicies.map((policy) => {
    const scan = {
      label: policy.label,
      type: policy.type,
      r: [],
      resourceRevenue: [],
      totalRevenue: [],
      gini: [],
      ecology: []
    };
    let bestIndex = 0;
    let bestValue = -Infinity;
    for (let i = 0; i < resolution; i += 1) {
      const regulation = i / Math.max(1, resolution - 1);
      const result = simulate(spec, { ...policy, regulation });
      scan.r.push(regulation);
      scan.resourceRevenue.push(result.summary.resourceRevenue);
      scan.totalRevenue.push(result.summary.totalRevenue);
      scan.gini.push(result.summary.gini);
      scan.ecology.push(result.summary.ecology);
      const score = result.summary.totalRevenue - result.summary.gini * 0.2 + result.summary.ecology * 0.1;
      if (score > bestValue) {
        bestValue = score;
        bestIndex = i;
      }
    }
    scan.optimal = {
      regulation: scan.r[bestIndex],
      totalRevenue: scan.totalRevenue[bestIndex],
      gini: scan.gini[bestIndex],
      ecology: scan.ecology[bestIndex]
    };
    return scan;
  });
}

export function policyControlSchema() {
  return {
    OpenAccess: [],
    ExclusiveUseRights: [
      { key: "selector", label: "Selector", type: "select", options: ["top", "bottom"] }
    ],
    TradableUseRights: [
      { key: "target", label: "Target", type: "select", options: ["effort", "yield"] },
      { key: "marketRate", label: "Market Rate", type: "range", min: 0.01, max: 0.2, step: 0.01 }
    ],
    ProtectedArea: [
      { key: "mobility", label: "Mobility", type: "range", min: 0.05, max: 1, step: 0.05 }
    ],
    EconomicIncentives: [
      { key: "target", label: "Target", type: "select", options: ["cost", "limit"] },
      { key: "method", label: "Method", type: "select", options: ["multiplicative", "taxation"] }
    ],
    Development: [
      { key: "muValue", label: "μ effect", type: "range", min: 0.05, max: 1, step: 0.05 },
      { key: "gammaValue", label: "γ effect", type: "range", min: 0.05, max: 1, step: 0.05 }
    ]
  };
}

export function sanitizeSpec(spec) {
  const next = structuredClone(spec);
  next.nodes = next.nodes.map((node, index) => ({
    ...node,
    id: sanitizeNodeId(node.id || `node_${index + 1}`),
    label: node.label || node.id || `Node ${index + 1}`
  }));
  return next;
}
