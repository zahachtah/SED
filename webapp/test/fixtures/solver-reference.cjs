// Frozen pre-optimization integrator for numerical and trajectory regression tests.
// Policy transforms remain covered by model.test.cjs and the Julia parity suite.
const { transform, policyActive, pressureScale } = require("../../model.js");
const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
const sum = xs => xs.reduce((a, b) => a + b, 0);
const mean = xs => sum(xs) / Math.max(1, xs.length);
function gini(values) {
    const a = values.slice().sort((a, b) => a - b), total = sum(a), n = a.length;
    return total > 0 ? 2 * sum(a.map((v, i) => (i + 1) * v)) / (n * total) - (n + 1) / n : null;
}

function solve(base, p, open = null, onProgress = null) {
    const actors = transform(base, p, open), n = actors.length, d = n + 2;
    const active = policyActive(p), isPA = active && p.policy === "pa", isRights = active && p.policy === "rights";
    const depletionPossible = !isPA && sum(actors.filter(a => a.cost === 0).map(a => a.limit)) >= 1;
    let state = new Float64Array(d), next = new Float64Array(d);
    const initial = open ? open.state : null;
    state[n] = initial ? initial[n] : 1;
    for (let i = 0; i < n; i++) state[i] = initial ? initial[i] : 0;
    if (isPA && initial) {
        const scale = pressureScale(state[n], p.protected, p.mobility);
        for (let i = 0; i < n; i++) state[i] *= scale;
    }
    const k1 = new Float64Array(d), k2 = new Float64Array(d), k3 = new Float64Array(d), k4 = new Float64Array(d);
    const stage = new Float64Array(d), second = new Float64Array(d);
    const maxTime = 6000, minTime = 35, alpha = p.alpha || 0.05;
    let time = 0, h = 0.03, steps = 0, converged = false, residual = Infinity;
    const path = [];
    const project = s => {
        s[n] = clamp(s[n], 0, 1);
        s[n + 1] = Math.max(0, s[n + 1]);
        const scale = isPA ? pressureScale(s[n], p.protected, p.mobility) : 1;
        for (let i = 0; i < n; i++) s[i] = clamp(s[i], 0, actors[i].limit * scale);
    };
    const derivative = (s, out) => {
        const y = s[n], price = s[n + 1];
        const scale = isPA ? pressureScale(y, p.protected, p.mobility) : 1;
        const wedge = isRights ? (p.target === "yield" ? y * price : price) : 0;
        let use = 0;
        for (let i = 0; i < n; i++) {
            use += s[i];
            let du = alpha * (y - actors[i].cost - wedge);
            if ((s[i] <= 0 && du < 0) || (s[i] >= actors[i].limit * scale && du > 0)) du = 0;
            out[i] = du;
        }
        out[n] = y * (1 - y - use);
        const priceRate = isRights ? 0.05 * ((p.target === "yield" ? y * use : use) - p.quota) : 0;
        out[n + 1] = price <= 1e-10 && priceRate < 0 ? 0 : priceRate;
    };
    const point = s => {
        const scale = isPA ? pressureScale(s[n], p.protected, p.mobility) : 1;
        let participation = 0, pressure = 0;
        for (let i = 0; i < n; i++) {
            pressure += s[i];
            participation += actors[i].limit * scale > 0 ? s[i] / (actors[i].limit * scale) : 0;
        }
        return { y: s[n], participation: participation / n, pressure, price: s[n + 1], t: time };
    };
    const addPoint = force => {
        const pt = point(state), last = path[path.length - 1];
        if (!last || force || Math.hypot(pt.y - last.y, pt.participation - last.participation) >= 0.001) path.push(pt);
    };
    project(state);
    addPoint(true);
    for (let attempt = 0; attempt < 450000 && time < maxTime; attempt++) {
        h = Math.min(h, maxTime - time);
        derivative(state, k1);
        if (p.solver === "euler") {
            h = 0.005;
            for (let j = 0; j < d; j++) next[j] = state[j] + h * k1[j];
            project(next);
        } else {
            for (let j = 0; j < d; j++) stage[j] = state[j] + h * 0.5 * k1[j];
            project(stage); derivative(stage, k2);
            for (let j = 0; j < d; j++) stage[j] = state[j] + h * 0.75 * k2[j];
            project(stage); derivative(stage, k3);
            for (let j = 0; j < d; j++) next[j] = state[j] + h * (2 / 9 * k1[j] + 1 / 3 * k2[j] + 4 / 9 * k3[j]);
            project(next); derivative(next, k4);
            let error = 0;
            for (let j = 0; j < d; j++) second[j] = state[j] + h * (7 / 24 * k1[j] + 0.25 * k2[j] + 1 / 3 * k3[j] + 0.125 * k4[j]);
            project(second);
            for (let j = 0; j < d; j++) {
                const tol = 1e-8 + 2e-6 * Math.max(Math.abs(state[j]), Math.abs(next[j]));
                error = Math.max(error, Math.abs(next[j] - second[j]) / tol);
            }
            const newH = clamp(h * (error < 1e-12 ? 3 : clamp(0.9 * error ** (-1 / 3), 0.3, 3)), 1e-5, 0.6);
            if (error > 1 && h > 1.001e-5) { h = newH; continue; }
            const usedH = h; h = newH; time += usedH;
        }
        if (p.solver === "euler") time += h;
        [state, next] = [next, state];
        steps++;
        if (steps % 2 === 0) addPoint(false);
        if (time > minTime && steps % 8 === 0) {
            derivative(state, k1);
            const pressure = sum(Array.from(state.slice(0, n)));
            // A tiny stock can have a tiny dy without being near balance.
            const atBoundary = depletionPossible && state[n] < 1e-8;
            residual = Math.max(...k1.map(Math.abs), atBoundary ? 0 : Math.abs(1 - state[n] - pressure));
            if (residual < 8e-8) { converged = true; break; }
        }
        if (steps % 8000 === 0 && onProgress) onProgress({ stage: "integrating", time, steps });
    }
    addPoint(true);
    const y = state[n], price = isRights ? state[n + 1] : 0;
    const scale = isPA ? pressureScale(y, p.protected, p.mobility) : 1;
    actors.forEach((a, i) => {
        a.use = state[i];
        a.physicalUse = isPA ? clamp(a.use / Math.max(scale, 1e-15), 0, a.potential) : a.use;
        a.fraction = a.limit * scale > 0 ? a.use / (a.limit * scale) : 0;
        a.resource = a.physicalUse * y * a.factor;
        a.wages = Math.max(0, a.endowment - a.physicalUse) * a.wageCost;
        a.outsideOnly = a.endowment * a.wageCost;
        const quotaUse = p.target === "yield" ? a.use * y : a.use;
        a.trade = isRights ? (a.right - quotaUse) * price : 0;
        a.total = a.resource + a.wages + a.trade;
        a.effectiveTheta = a.cost + (isRights ? (p.target === "yield" ? y * price : price) : 0);
        a.effectivePotential = a.limit * scale;
    });
    const pressure = sum(Array.from(state.slice(0, n)));
    const quotaUse = isRights ? pressure * (p.target === "yield" ? y : 1) : 0;
    const result = { actors, state: Array.from(state), y, pressure, price, participation: mean(actors.map(a => a.fraction)),
        resource: sum(actors.map(a => a.resource)), total: sum(actors.map(a => a.total)),
        inequality: gini(actors.map(a => a.total)), time, steps, converged, residual, path,
        boundary: depletionPossible && y < 1e-8,
        quotaUse, quotaResidual: isRights ? quotaUse - p.quota : 0,
        transferBalance: sum(actors.map(a => a.trade)), policyImpact: open ? sum(actors.map((a, i) => Math.abs(a.use - open.state[i]))) : 0 };
    return result;
}

module.exports = solve;

