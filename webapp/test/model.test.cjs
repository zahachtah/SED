const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const M = require("../model.js");
let checks = 0;
function check(title, fn) { fn(); checks++; console.log(`PASS ${title}`); }
function close(a, b, tolerance = 1e-5) { assert.ok(Math.abs(a - b) < tolerance, `${a} differs from ${b} by ${Math.abs(a - b)}`); }
const p = { ...M.defaults, n: 120 };

check("ordered and random marginals describe the same distribution", () => {
    const q = { ...p, n: 1000 }, ordered = M.population(q), random = M.population({ ...q, thresholdSampling: "random", impactSampling: "random" });
    close(M.moments(ordered.map(a => a.theta)).mean, q.meanTheta, 1e-12);
    close(M.moments(random.map(a => a.theta)).mean, q.meanTheta, 1e-12);
    close(ordered.reduce((s, a) => s + a.potential, 0), q.totalImpact, 1e-12);
    for (const x of [.2, .4, .6, .8, 1]) close(ordered.filter(a => a.theta < x).length / q.n, random.filter(a => a.theta < x).length / q.n, .045);
});
check("zero threshold and heterogeneity are exactly attainable", () => {
    const a = M.population({ ...p, meanTheta: 0, thetaSpread: 0, impactSpread: 0 });
    assert.ok(a.every(a => a.theta === 0));
    a.forEach(a => close(a.potential, p.totalImpact / p.n, 1e-12));
});
check("pairing preserves both ordered marginal distributions", () => {
    const a = M.population({ ...p, correlation: -.9 }), b = M.population({ ...p, correlation: .9 });
    const sorted = (a, k) => a.map(a => a[k]).sort((a, b) => a - b);
    assert.deepEqual(sorted(a, "theta"), sorted(b, "theta"));
    sorted(a, "potential").forEach((v, i) => close(v, sorted(b, "potential")[i], 1e-12));
    assert.ok(M.correlation(a.map(a => a.theta), a.map(a => a.potential)) < 0);
    assert.ok(M.correlation(b.map(a => a.theta), b.map(a => a.potential)) > 0);
});
check("the cumulative curve is not normalized to the plotting window", () => {
    const a = M.population({ ...p, meanTheta: 1.5 });
    const result = M.solve(a, { ...p, meanTheta: 1.5 });
    const curve = M.curves(result, p);
    assert.ok(curve.at(-1).participation < .5);
});
check("zero thresholds can reach a genuine depleted-resource boundary", () => {
    const result = M.run({ ...p, meanTheta: 0, thetaSpread: 0, totalImpact: 1.4 });
    assert.ok(result.open.converged);
    assert.ok(result.open.boundary);
    assert.ok(result.open.y < 1e-8);
});
check("infeasible sustainable participation is undefined", () => {
    const a = M.population({ ...p, totalImpact: .2 });
    const r = M.solve(a, { ...p, totalImpact: .2 });
    const curve = M.curves(r, p);
    assert.ok(Number.isNaN(curve[0].required));
    close(curve.at(-1).required, 0, 1e-12);
});
let baseline;
check("the open-access simulation converges and stays feasible", () => {
    baseline = M.run(p);
    assert.ok(baseline.open.converged);
    close(baseline.open.pressure, 1 - baseline.open.y, 2e-6);
    baseline.open.actors.forEach(a => assert.ok(a.use >= 0 && a.use <= a.potential + 1e-10));
    close(baseline.open.path[0].y, 1, 1e-12);
    close(baseline.open.path[0].participation, 0, 1e-12);
});
check("zero-intensity policies collapse to the open-access equations", () => {
    const cases = [{ policy: "access", exclusion: 0 }, { policy: "pa", protected: 0 },
        { policy: "rights", quota: 1 }, { policy: "economic", royalty: 0, gear: 0, effort: 0, outside: 0 }];
    for (const q of cases) {
        const r = M.run({ ...p, ...q }, baseline.open).policy;
        close(r.y, baseline.open.y, 5e-6);
        close(r.total, baseline.open.total, 5e-6);
        close(r.price, 0, 1e-12);
    }
});
check("tradable quotas bind, price evolves, and transfers balance", () => {
    for (const target of ["effort", "yield"]) {
        const q = { ...p, policy: "rights", target, quota: target === "yield" ? .18 : .5 };
        const r = M.run(q).policy;
        assert.ok(r.converged);
        close(r.quotaResidual, 0, 3e-5);
        close(r.transferBalance, 0, 3e-5);
        assert.ok(r.price > 0);
        const h = M.run({ ...q, historical: true }).policy;
        close(h.y, r.y, 2e-4);
        close(h.resource, r.resource, 2e-4);
        assert.ok(Math.abs(h.inequality - r.inequality) > 1e-4);
        close(r.path[0].y, baseline.open.y, 5e-6);
    }
});
check("protected-area income recovers physical use and original endowment", () => {
    const q = { ...p, policy: "pa", protected: .3, mobility: .3 }, r = M.run(q).policy;
    assert.ok(r.converged);
    const k = M.pressureScale(r.y, q.protected, q.mobility);
    for (const a of r.actors) {
        close(a.physicalUse, a.use / k, 1e-10);
        close(a.resource, a.physicalUse * r.y * (1 - q.protected), 1e-10);
        close(a.wages, (a.potential - a.physicalUse) * a.theta, 1e-10);
    }
});
check("a literal gear change transforms both thresholds and impact potential", () => {
    const q = { ...p, policy: "economic", gear: .4, royalty: 0 }, a = M.transform(M.population(p), q);
    a.forEach(a => { close(a.cost, a.theta / 1.4, 1e-12); close(a.limit, a.potential * 1.4, 1e-12); close(a.endowment * a.wageCost, a.potential * a.theta, 1e-12); });
});
check("income decompositions preserve revenue, rent, outside earnings, and receipts", () => {
    for (const change of [{}, {policy:"economic",royalty:.3}, {policy:"economic",gear:.5,royalty:0},
        {policy:"economic",gear:-.3,effort:.2,outside:.3}, {policy:"pa",protected:.4,tourism:.2},
        {policy:"rights",quota:.4}, {policy:"rights",target:"yield",quota:.18,historical:true}]) {
        const q={...p,...change}, run=M.run(q), r=run.policy;
        for (const a of r.actors) {
            close(a.resourceRent,a.resource-a.opportunityCost,1e-12);
            close(a.wages,a.outsideOnly-a.opportunityCost,1e-12);
            close(a.total,a.outsideOnly+a.resourceRent+a.trade,1e-12);
            close(a.grossResourceRevenue,a.resource+a.stateRevenue,1e-12);
            close(a.netResourceRent,a.resourceRent+a.trade,1e-12);
        }
        close(r.resourceRent,r.actors.reduce((s,a)=>s+a.resourceRent,0),1e-12);
        close(r.total+r.stateRevenue,r.grossResourceRevenue+r.outsideIncome+r.transferBalance,1e-12);
        if(q.policy==="economic"&&q.gear) {
            const expected=r.actors.reduce((s,a,i)=>s+Math.min(a.limit,(1+q.gear)*run.open.state[i]),0);
            close(r.path[0].pressure,expected,1e-12);
            close(r.path[0].y,run.open.y,1e-12);
        }
    }
});
check("causal quantities are derived actor by actor without marginal renormalization", () => {
    const c = structuredClone(M.causalDefaults), a = M.causalPopulation(p, c);
    a.forEach(a => { close(a.theta, a.w / (c.p * a.q * c.K), 1e-12); close(a.potential, a.q * a.e / c.r, 1e-12); });
    c.coefficients.capital[1] = .3;
    const b = M.causalPopulation(p, c);
    assert.ok(Math.abs(M.correlation(a.map(a => a.theta), a.map(a => a.potential)) - M.correlation(b.map(a => a.theta), b.map(a => a.potential))) > .2);
    assert.deepEqual(a.map(a => [a.health, a.gender, a.care]), b.map(a => [a.health, a.gender, a.care]));
});
check("path spacing changes plotted sample counts, not endpoints", () => {
    const dense = M.resamplePath(baseline.open.path, .005), sparse = M.resamplePath(baseline.open.path, .1);
    assert.ok(dense.length > sparse.length * 5);
    assert.deepEqual(dense.at(-1), sparse.at(-1));
    for (let i = 1; i < dense.length; i++) assert.ok(Math.hypot(dense[i].y - dense[i - 1].y, dense[i].participation - dense[i - 1].participation) <= .005001);
});
check("policy scans use stored components and reweight without simulation", () => {
    const q = { ...p, policy: "access", scan: true, scanPoints: 8 }, r = M.run(q);
    const before = JSON.stringify(r.scan), scores = M.scoreRows(r.scan, { ...q.weights, gini: -1 });
    assert.equal(Math.max(...scores), 1);
    assert.equal(JSON.stringify(r.scan), before);
    close(r.scan[0].result.y, r.open.y, 1e-5);
});
check("standalone worker engine has no dependency on DOM globals", () => {
    const source = fs.readFileSync(path.join(__dirname, "../model.js"), "utf8");
    const sandbox = {}; vm.createContext(sandbox);
    vm.runInContext(source + "; globalThis.result = SEDModel.run({...SEDModel.defaults,n:32}).open.y", sandbox);
    assert.ok(sandbox.result > 0 && sandbox.result < 1);
});

if (process.env.JULIA) {
    check("browser endpoints and curves match the current Julia package", () => {
        const run = spawnSync(process.env.JULIA, ["--project=.", "webapp/test/julia_reference.jl"], { cwd: path.resolve(__dirname, "../.."), encoding: "utf8", timeout: 180000, env: process.env });
        assert.equal(run.status, 0, run.stderr);
        const n = 32, raw = Array.from({ length: n }, (_, i) => .2 + 2.2 * (i + 1) / (n + 1));
        const records = raw.map((v, i) => ({ id: i, theta: .08 + .85 * ((i + 1) / (n + 1)) ** 2, potential: v / raw.reduce((s, a) => s + a, 0) * 1.4 }));
        const q = { ...M.defaults, n, populationMode: "imported", records };
        const cases = { none: {}, access: { policy: "access", selector: "low", exclusion: .375 },
            rights: { policy: "rights", quota: .5 }, rights_historical: { policy: "rights", quota: .5, historical: true },
            catch: { policy: "rights", target: "yield", quota: .18 }, pa: { policy: "pa", protected: .3, mobility: .3 },
            economic: { policy: "economic", royalty: .2, gear: .35 },
            royalty: {policy:"economic",royalty:.3}, gear: {policy:"economic",royalty:0,gear:.5},
            effort: {policy:"economic",royalty:0,effort:-.3}, outside: {policy:"economic",royalty:0,outside:.4} };
        const seen = new Set();
        const results = new Map();
        for (const line of run.stdout.trim().split("\n").filter(s => Object.keys(cases).some(k => s.startsWith(k + ",")))) {
            const [name, ...values] = line.split(","), expected = values.map(Number), params = { ...q, ...cases[name] };
            seen.add(name);
            const result = M.run(params).policy;
            results.set(name,result);
            const observed = [result.y, result.participation, result.pressure, result.resource, result.total, result.price,
                result.resourceRent,result.opportunityCost,result.outsideIncome,result.outsideIncome0,result.stateRevenue,result.grossResourceRevenue];
            const curve = M.curves(result, params);
            // Compare away from threshold jumps, whose two valid boundaries
            // can differ by one actor under tiny price rounding differences.
            for (const level of [.21, .51, .81]) { const point = curve[Math.round(level * 400)]; observed.push(point.participation, point.required); }
            expected.forEach((v, i) => { if (Number.isNaN(v)) assert.ok(Number.isNaN(observed[i])); else close(observed[i], v, i < 12 ? 4e-4 : 6e-4); });
            console.log(`  Julia parity: ${name}`);
        }
        assert.deepEqual([...seen].sort(), Object.keys(cases).sort(), "every Julia reference case must be compared");
        let actorChecks=0;
        for(const line of run.stdout.split("\n").filter(s=>s.startsWith("actor,"))) {
            const [,name,id,...values]=line.split(","), a=results.get(name).actors[Number(id)];
            const observed=[a.resource,a.resourceRent,a.opportunityCost,a.wages,a.outsideOnly,a.trade,a.stateRevenue,a.total,a.grossResourceRevenue];
            values.map(Number).forEach((v,i)=>close(observed[i],v,4e-4));
            actorChecks++;
        }
        assert.equal(actorChecks,n*Object.keys(cases).length);
        console.log(`  Actor-component parity: ${actorChecks} actor/scenario comparisons`);
    });
}
console.log(`${checks} model checks passed.`);
