/* SED companion engine. Paper notation is used at the browser boundary. */
function createSEDModel() {
    "use strict";
    const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
    const sum = xs => xs.reduce((a, b) => a + b, 0);
    const mean = xs => sum(xs) / Math.max(1, xs.length);
    const defaults = {
        n: 320, seed: 17, alpha: 0.05, solver: "rk23", spacing: 0.012,
        thresholdSampling: "ordered", impactSampling: "ordered",
        meanTheta: 0.45, thetaSpread: 0.65, totalImpact: 1.35,
        impactSpread: 0.8, correlation: -0.3, populationMode: "direct",
        policy: "none", exclusion: 0.3, selector: "high",
        quota: 0.5, target: "effort", historical: false,
        protected: 0.25, mobility: 0.3, tourism: 0,
        economicMode: "royalty", royalty: 0.2, gear: 0, effort: 0, outside: 0,
        view: "balance", densities: false, path: true, incomeSort: "total",
        incomeView: "levels", logIncome: false, scan: false, scanPoints: 20,
        weights: { resource: 0.5, total: 1, gini: -0.2, ecology: 0, impact: 0 }
    };
    const causalDefaults = {
        w: 0.42, q: 1, e: 0.0042, p: 1, K: 1, r: 1, noise: 0.22,
        // These are illustrative context-dependent relationships, not estimates.
        coefficients: {
            health: [0.65, 0.3, 0.55],
            gender: [-0.55, -0.15, -0.2],
            care: [-0.35, 0, -0.75],
            capital: [0.65, 0.9, 0.05]
        }
    };

    function rng(seed) {
        let a = seed >>> 0;
        return () => {
            a += 0x6D2B79F5;
            let t = Math.imul(a ^ a >>> 15, 1 | a);
            t ^= t + Math.imul(t ^ t >>> 7, 61 | t);
            return ((t ^ t >>> 14) >>> 0) / 4294967296;
        };
    }

    function normalQuantile(p) {
        const a = [-39.6968302866538, 220.946098424521, -275.928510446969, 138.357751867269, -30.6647980661472, 2.50662827745924];
        const b = [-54.4760987982241, 161.585836858041, -155.698979859887, 66.8013118877197, -13.2806815528857];
        const c = [-0.00778489400243029, -0.322396458041136, -2.40075827716184, -2.54973253934373, 4.37466414146497, 2.93816398269878];
        const d = [0.00778469570904146, 0.32246712907004, 2.445134137143, 3.75440866190742];
        p = clamp(p, 1e-10, 1 - 1e-10);
        const tail = q => (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
            ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
        if (p < 0.02425) return tail(Math.sqrt(-2 * Math.log(p)));
        if (p > 0.97575) return -tail(Math.sqrt(-2 * Math.log(1 - p)));
        const q = p - 0.5, r = q * q;
        return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q /
            (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1);
    }

    function halton(i, base) {
        let result = 0, f = 1;
        for (; i > 0; i = Math.floor(i / base)) {
            f /= base;
            result += f * (i % base);
        }
        return result;
    }

    const sortedIndices = values => values.map((_, i) => i).sort((i, j) => values[i] - values[j] || i - j);
    function rankQuantiles(scores) {
        const out = new Array(scores.length);
        sortedIndices(scores).forEach((index, rank) => {
            out[index] = normalQuantile((rank + 1) / (scores.length + 1));
        });
        return out;
    }

    function moments(values) {
        const a = values.filter(Number.isFinite).slice().sort((a, b) => a - b);
        const m = mean(a), n = a.length;
        return { mean: m, median: n ? (a[Math.floor((n - 1) / 2)] + a[Math.floor(n / 2)]) / 2 : 0,
            variance: mean(a.map(x => (x - m) ** 2)) };
    }

    function correlation(x, y) {
        const mx = mean(x), my = mean(y);
        let xx = 0, yy = 0, xy = 0;
        x.forEach((v, i) => { xx += (v - mx) ** 2; yy += (y[i] - my) ** 2; xy += (v - mx) * (y[i] - my); });
        return xx * yy > 1e-24 ? xy / Math.sqrt(xx * yy) : 0;
    }

    function population(p) {
        if (p.populationMode === "imported" && p.records?.length) {
            return p.records.map((a, id) => ({ ...a, id, rank: a.rank ?? id / p.records.length }));
        }
        if (p.populationMode === "causal") return causalPopulation(p, p.causal || causalDefaults);
        const random = rng(p.seed), n = p.n;
        const deterministic = p.thresholdSampling === "ordered" && p.impactSampling === "ordered";
        const z = [], zi = [], rho = clamp(p.correlation, -0.999, 0.999);
        for (let i = 0; i < n; i++) {
            const z1 = normalQuantile(deterministic ? halton(i + 1, 2) : random());
            const z2 = normalQuantile(deterministic ? halton(i + 1, 3) : random());
            z.push(z1);
            zi.push(rho * z1 + Math.sqrt(1 - rho * rho) * z2);
        }
        const thetaScores = p.thresholdSampling === "ordered" ? rankQuantiles(z) : z;
        const impactScores = p.impactSampling === "ordered" ? rankQuantiles(zi) : zi;
        const thresholds = thetaScores.map(v => Math.exp(p.thetaSpread * v - p.thetaSpread ** 2 / 2));
        const impacts = impactScores.map(v => Math.exp(p.impactSpread * v));
        const thresholdScale = p.meanTheta / mean(thresholds), impactScale = p.totalImpact / sum(impacts);
        return thresholds.map((t, i) => ({ id: i, theta: t * thresholdScale,
            potential: impacts[i] * impactScale, rank: random(), group: null }));
    }

    function causalPopulation(p, c) {
        const random = rng(p.seed), actors = [];
        const lognormal = (m, b, sigma, z) => m * Math.exp(b + sigma * z - sigma ** 2 / 2);
        for (let i = 0; i < p.n; i++) {
            const health = 0.2 + 0.8 * random();
            const gender = random() < 0.5 ? 1 : 0;
            const care = random() < (0.25 + 0.35 * gender) ? 1 : 0;
            const capital = normalQuantile(random());
            const centered = [health - 0.6, gender - 0.5, care - 0.425, capital];
            const keys = ["health", "gender", "care", "capital"];
            const effects = [0, 0, 0];
            keys.forEach((key, j) => c.coefficients[key].forEach((b, k) => effects[k] += b * centered[j]));
            const w = lognormal(c.w, effects[0], c.noise, normalQuantile(random()));
            const q = lognormal(c.q, effects[1], c.noise, normalQuantile(random()));
            const e = lognormal(c.e, effects[2], c.noise, normalQuantile(random()));
            actors.push({ id: i, theta: w / (c.p * q * c.K), potential: q * e / c.r,
                w, q, e, health, gender, care, capital, rank: random(),
                group: gender ? "Group with access constraints" : "Comparison group" });
        }
        return actors;
    }

    function protectedStock(y, mobility) {
        return ((1 - mobility) + Math.sqrt((1 - mobility) ** 2 + 4 * mobility * y)) / 2;
    }
    function pressureScale(y, fraction, mobility) {
        if (fraction === 0 || mobility === 0) return 1;
        const z = clamp(y, 0, 1 - 1e-8), replacement = 1 - z;
        const h = fraction / (1 - fraction) * mobility * (protectedStock(z, mobility) - z) / Math.max(z, 1e-6);
        return clamp(replacement / Math.max(replacement + h, Number.EPSILON), 0, 1);
    }
    function policyActive(p) {
        if (p.policy === "none") return false;
        if (p.policy === "access") return p.exclusion > 0;
        if (p.policy === "pa") return p.protected > 0;
        if (p.policy === "rights") return p.quota < (p.target === "yield" ? 0.5 : 1);
        if (p.policy === "economic") return !!(p.royalty || p.gear || p.effort || p.outside);
        return false;
    }

    function transform(base, p, open) {
        const active = policyActive(p);
        const a = base.map(row => ({ ...row, cost: row.theta, limit: row.potential,
            wageCost: row.theta, endowment: row.potential, factor: 1, excluded: false, right: 0 }));
        if (!active) return a;
        if (p.policy === "access") {
            const order = a.slice().sort((x, y) => p.selector === "low" ? x.theta - y.theta :
                p.selector === "random" ? x.rank - y.rank : y.theta - x.theta);
            order.slice(0, Math.round(p.exclusion * a.length)).forEach(row => { row.cost += 1; row.excluded = true; });
        }
        if (p.policy === "pa") {
            a.forEach(row => { row.wageCost *= 1 + (p.tourism || 0); row.cost = row.wageCost / (1 - p.protected); row.factor = 1 - p.protected; });
        }
        if (p.policy === "economic") {
            const g = 1 + p.gear, e = 1 + (p.effort || 0), w = 1 + (p.outside || 0);
            a.forEach(row => {
                row.cost *= w / ((1 - p.royalty) * g);
                row.limit *= g * e;
                row.endowment = row.limit;
                row.wageCost *= w / g;
                row.factor = 1 - p.royalty;
            });
        }
        if (p.policy === "rights") {
            const historical = a.map((_, i) => !p.historical || (open?.actors[i]?.use || 0) > 0);
            let count = historical.filter(Boolean).length;
            if (!count) { historical.fill(true); count = a.length; }
            a.forEach((row, i) => row.right = historical[i] ? p.quota / count : 0);
        }
        return a;
    }

    function gini(values) {
        const a = values.slice().sort((a, b) => a - b), total = sum(a), n = a.length;
        return total > 0 ? 2 * sum(a.map((v, i) => (i + 1) * v)) / (n * total) - (n + 1) / n : null;
    }

    function solve(base, p, open = null, onProgress = null) {
        const actors = transform(base, p, open), n = actors.length, d = n + 2;
        const costs = Float64Array.from(actors, a => a.cost), limits = Float64Array.from(actors, a => a.limit);
        const active = policyActive(p), isPA = active && p.policy === "pa", isRights = active && p.policy === "rights";
        const depletionPossible = !isPA && sum(actors.filter(a => a.cost === 0).map(a => a.limit)) >= 1;
        let state = new Float64Array(d), next = new Float64Array(d);
        const initial = open ? open.state : null;
        state[n] = initial ? initial[n] : 1;
        const initialGear = active && p.policy === "economic" ? 1 + p.gear : 1;
        for (let i = 0; i < n; i++) state[i] = initial ? initial[i] * initialGear : 0;
        if (isPA && initial) {
            const scale = pressureScale(state[n], p.protected, p.mobility);
            for (let i = 0; i < n; i++) state[i] *= scale;
        }
        let k1 = new Float64Array(d), k4 = new Float64Array(d);
        const k2 = new Float64Array(d), k3 = new Float64Array(d);
        const stage = new Float64Array(d), second = new Float64Array(d);
        const maxTime = 6000, minTime = 35, alpha = p.alpha || 0.05, euler = p.solver === "euler";
        let time = 0, h = 0.03, steps = 0, converged = false, residual = Infinity;
        const path = [];
        const project = s => {
            s[n] = clamp(s[n], 0, 1);
            s[n + 1] = Math.max(0, s[n + 1]);
            const scale = isPA ? pressureScale(s[n], p.protected, p.mobility) : 1;
            for (let i = 0; i < n; i++) s[i] = clamp(s[i], 0, limits[i] * scale);
        };
        const derivative = (s, out) => {
            const y = s[n], price = s[n + 1];
            const scale = isPA ? pressureScale(y, p.protected, p.mobility) : 1;
            const wedge = isRights ? (p.target === "yield" ? y * price : price) : 0;
            let use = 0;
            for (let i = 0; i < n; i++) {
                use += s[i];
                let du = alpha * (y - costs[i] - wedge);
                if ((s[i] <= 0 && du < 0) || (s[i] >= limits[i] * scale && du > 0)) du = 0;
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
                participation += limits[i] * scale > 0 ? s[i] / (limits[i] * scale) : 0;
            }
            return { y: s[n], participation: participation / n, pressure, price: s[n + 1], t: time };
        };
        const addPoint = force => {
            const pt = point(state), last = path[path.length - 1];
            if (!last || force || Math.hypot(pt.y - last.y, pt.participation - last.participation) >= 0.001) path.push(pt);
        };
        project(state);
        addPoint(true);
        if (!euler) derivative(state, k1);
        for (let attempt = 0; attempt < 450000 && time < maxTime; attempt++) {
            h = Math.min(h, maxTime - time);
            if (euler) {
                derivative(state, k1);
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
            if (euler) time += h;
            const previous = state; state = next; next = previous;
            // RK23's last stage is the derivative of the accepted, projected state.
            // Rejected attempts leave k1 valid; accepted steps reuse k4 as k1.
            if (!euler) { const first = k1; k1 = k4; k4 = first; }
            steps++;
            if (steps % 2 === 0) addPoint(false);
            if (time > minTime && steps % 8 === 0) {
                if (euler) derivative(state, k1);
                let pressure = 0;
                residual = 0;
                for (let j = 0; j < d; j++) {
                    residual = Math.max(residual, Math.abs(k1[j]));
                    if (j < n) pressure += state[j];
                }
                // A tiny stock can have a tiny dy without being near balance.
                const atBoundary = depletionPossible && state[n] < 1e-8;
                residual = Math.max(residual, atBoundary ? 0 : Math.abs(1 - state[n] - pressure));
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
            a.opportunityCost = a.physicalUse * a.wageCost;
            a.resourceRent = a.resource - a.opportunityCost;
            a.stateRevenue = active && p.policy === "economic" ? a.physicalUse * y * p.royalty : 0;
            a.grossResourceRevenue = a.resource + a.stateRevenue;
            const quotaUse = p.target === "yield" ? a.use * y : a.use;
            a.trade = isRights ? (a.right - quotaUse) * price : 0;
            a.netResourceRent = a.resourceRent + a.trade;
            a.total = a.resource + a.wages + a.trade;
            a.effectiveTheta = a.cost + (isRights ? (p.target === "yield" ? y * price : price) : 0);
            a.effectivePotential = a.limit * scale;
        });
        let pressure = 0;
        for (let i = 0; i < n; i++) pressure += state[i];
        const quotaUse = isRights ? pressure * (p.target === "yield" ? y : 1) : 0;
        const result = { actors, state: Array.from(state), y, pressure, price, participation: mean(actors.map(a => a.fraction)),
            resource: sum(actors.map(a => a.resource)), total: sum(actors.map(a => a.total)),
            resourceRent: sum(actors.map(a => a.resourceRent)),
            opportunityCost: sum(actors.map(a => a.opportunityCost)),
            outsideIncome: sum(actors.map(a => a.wages)), outsideIncome0: sum(actors.map(a => a.outsideOnly)),
            stateRevenue: sum(actors.map(a => a.stateRevenue)),
            grossResourceRevenue: sum(actors.map(a => a.grossResourceRevenue)),
            inequality: gini(actors.map(a => a.total)), time, steps, converged, residual, path,
            boundary: depletionPossible && y < 1e-8,
            quotaUse, quotaResidual: isRights ? quotaUse - p.quota : 0,
            transferBalance: sum(actors.map(a => a.trade)), policyImpact: open ? sum(actors.map((a, i) => Math.abs(a.use - open.state[i]))) : 0 };
        return result;
    }

    function curves(result, p, resolution = 400) {
        const active = policyActive(p), n = result.actors.length;
        const rows = result.actors.slice().sort((a, b) => a.cost - b.cost || a.id - b.id);
        const points = [];
        for (let j = 0; j <= resolution; j++) {
            const y = j / resolution, wedge = active && p.policy === "rights" ? result.price * (p.target === "yield" ? y : 1) : 0;
            const eligible = rows.filter(a => a.cost + wedge <= 1);
            const count = rows.filter(a => a.cost + wedge < y).length;
            const scale = active && p.policy === "pa" ? pressureScale(y, p.protected, p.mobility) : 1;
            let target = 1 - y, fraction = 0;
            let required = target <= 0 ? 0 : NaN;
            if (target > 0) {
                for (const a of eligible) {
                    const limit = a.limit * scale;
                    if (target <= limit + 1e-13 && limit > 0) { fraction += Math.max(0, target) / limit; target = 0; break; }
                    target -= limit;
                    fraction++;
                }
                if (target <= 1e-12) required = Math.min(fraction / n, eligible.length / n);
            }
            points.push({ y, participation: count / n, required });
        }
        return points;
    }

    function resamplePath(path, spacing) {
        if (path.length < 2) return path.slice();
        const out = [path[0]];
        let distance = 0;
        for (let i = 1; i < path.length; i++) {
            let a = path[i - 1], b = path[i];
            let length = Math.hypot(b.y - a.y, b.participation - a.participation);
            while (length > 1e-12 && distance + length >= spacing) {
                const f = (spacing - distance) / length;
                const pt = {};
                for (const key of ["y", "participation", "pressure", "price", "t"]) pt[key] = a[key] + f * (b[key] - a[key]);
                out.push(pt); a = pt;
                length = Math.hypot(b.y - a.y, b.participation - a.participation); distance = 0;
            }
            distance += length;
        }
        const last = path[path.length - 1];
        if (Math.hypot(last.y - out[out.length - 1].y, last.participation - out[out.length - 1].participation) > 1e-8) out.push(last);
        return out;
    }

    function scanParams(p, strength) {
        const q = { ...p, scan: false };
        if (p.policy === "access") q.exclusion = strength * 0.95;
        if (p.policy === "rights") q.quota = (p.target === "yield" ? 0.5 : 1) * (1 - strength);
        if (p.policy === "pa") q.protected = 0.8 * strength;
        if (p.policy === "economic") for (const k of ["royalty", "gear", "effort", "outside"]) q[k] = p[k] * strength;
        return q;
    }

    function scoreRows(rows, weights) {
        const scores = rows.map(r => Object.entries(weights).reduce((s, [k, w]) => {
            const v = k === "gini" ? r.result.inequality : k === "ecology" ? r.result.y : k === "impact" ? r.result.policyImpact : k === "resource" ? r.result.resourceRent : r.result[k];
            return s + w * Math.log(Math.max(1e-12, v ?? 0));
        }, 0));
        const max = Math.max(...scores);
        return scores.map(s => Math.exp(s - max));
    }

    function run(p, cachedOpen = null, onProgress = null) {
        const base = population(p), openParams = { ...p, policy: "none", scan: false };
        onProgress?.({ stage: "open" });
        const open = cachedOpen || solve(base, openParams, null, onProgress);
        onProgress?.({ stage: "policy" });
        const policy = p.policy === "none" ? open : solve(base, p, open, onProgress);
        const openCurves = curves(open, openParams);
        const data = { base, open, policy, params: p, curves: { open: openCurves, policy: policy === open ? openCurves : curves(policy, p) } };
        if (p.scan && p.policy !== "none") {
            data.scan = [];
            const n = Math.max(8, Math.min(64, p.scanPoints));
            for (let i = 0; i < n; i++) {
                const strength = i / n, q = scanParams(p, strength);
                const result = solve(base, q, open);
                data.scan.push({ strength, params: q, result });
                onProgress?.({ stage: "scan", completed: i + 1, total: n });
            }
        }
        return data;
    }

    function populationKey(p) {
        return JSON.stringify([p.n,p.seed,p.alpha,p.solver,p.thresholdSampling,p.impactSampling,p.meanTheta,
            p.thetaSpread,p.totalImpact,p.impactSpread,p.correlation,p.populationMode,p.causal,p.records]);
    }

    function createSession() {
        let key = null, open = null;
        return { run(p, cachedOpen = null, onProgress = null) {
            const nextKey = populationKey(p);
            const data = run(p, cachedOpen || (nextKey === key ? open : null), onProgress);
            key = nextKey;
            open = data.open;
            return data;
        } };
    }

    return { defaults, causalDefaults, population, causalPopulation, transform, pressureScale, protectedStock,
        solve, curves, run, createSession, populationKey, moments, correlation, resamplePath, scoreRows, scanParams, policyActive, rng, normalQuantile };
}

const SEDModel = createSEDModel();
if (typeof module !== "undefined") module.exports = SEDModel;
