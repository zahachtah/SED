const assert = require("node:assert/strict");
const { performance } = require("node:perf_hooks");
const M = require("../model.js");
const reference = require("./fixtures/solver-reference.cjs");

function referenceRun(p) {
    const base = M.population(p), openParams = { ...p, policy: "none", scan: false };
    const open = reference(base, openParams), policy = p.policy === "none" ? open : reference(base, p, open);
    const data = { base, open, policy, params: p, curves: { open: M.curves(open, openParams), policy: M.curves(policy, p) } };
    if (p.scan && p.policy !== "none") {
        data.scan = [];
        for (let i = 0; i < p.scanPoints; i++) {
            const strength = i / p.scanPoints, params = M.scanParams(p, strength);
            data.scan.push({ strength, params, result: reference(base, params, open) });
        }
    }
    return data;
}

const scenarios = [
    ["Open access", {}], ["Effort rights", { policy: "rights", quota: .25 }],
    ["Catch rights", { policy: "rights", target: "yield", quota: .1 }],
    ["Protected area", { policy: "pa", protected: .5, mobility: .3 }],
    ["20-point rights scan", { policy: "rights", scan: true, scanPoints: 20 }]
];
const median = values => values.sort((a, b) => a - b)[Math.floor(values.length / 2)];
console.log("Node end-to-end model timings, milliseconds (median of 7 interleaved runs after 3 warmups).");
console.log("Excludes browser rendering, worker startup, and message transport; no timing assertions.");
console.log("Actors | Case | Reference | Optimized | Speedup");
for (const n of [320, 1000]) for (const [name, change] of scenarios) {
    const p = { ...M.defaults, n, ...change }, times = [[], []], runs = [referenceRun, M.run];
    assert.deepEqual(M.run(p), referenceRun(p), `${name}: timing only equivalent calculations`);
    for (let i = 0; i < 10; i++) for (const k of i % 2 ? [1, 0] : [0, 1]) {
        const start = performance.now();
        runs[k](p);
        if (i >= 3) times[k].push(performance.now() - start);
    }
    const before = median(times[0]), after = median(times[1]);
    console.log(`${n} | ${name} | ${before.toFixed(2)} | ${after.toFixed(2)} | ${(before / after).toFixed(2)}x`);
}
