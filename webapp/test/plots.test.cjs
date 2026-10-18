const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const M = require("../model.js");

// Check numeric drawing geometry at narrow and wide sizes without a browser.
// Real typography and layout still require the Playwright visual checks.
let drawCalls = 0;
function context() {
    const noop = () => {};
    const finite = (...args) => { args.forEach(v => assert.ok(Number.isFinite(v))); drawCalls++; };
    return { save: noop, restore: noop, beginPath: noop, stroke: noop, fill: noop,
        clip: noop, rotate: finite, translate: finite, setTransform: finite,
        setLineDash: xs => xs.forEach(v => assert.ok(Number.isFinite(v))),
        moveTo: finite, lineTo: finite, rect: finite, fillRect: finite,
        arc: (x, y, r, a, b) => { finite(x, y, r, a, b); assert.ok(r >= 0); },
        fillText: (text, x, y) => { assert.equal(typeof text, "string"); finite(x, y); },
        measureText: s => ({ width: s.length * 5.8 }) };
}
function canvas(width, height) {
    return { getBoundingClientRect: () => ({ width, height }), getContext: () => context() };
}
const palette = { surface: "#fff", muted: "#718080", ink: "#202b2c", axis: "#bfcac5", grid: "#edf1ef", threshold: "#c97b24", impact: "#3273b0", ecology: "#17806b", baseline: "#9aabaa", rent: "#387d9d", opportunity: "#c7dfe8", alternative: "#c7cdce", transfer: "#81759d", red: "#bc5759", policy: "#75668d" };
const nodes = {};
const sandbox = { SEDModel: M, console, devicePixelRatio: 1,
    document: { body: {}, getElementById: id => nodes[id] },
    getComputedStyle: () => ({ getPropertyValue: key => palette[key.slice(2)] }) };
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.join(__dirname, "../plots.js"), "utf8") + "; globalThis.plots = SEDPlots;", sandbox);
const p = { ...M.defaults, n: 80 };
for (const width of [300, 450, 900, 1200]) {
    nodes.phaseCanvas = canvas(width, 330);
    nodes.incomeCanvas = canvas(width, 250);
    for (const policy of ["none", "access", "rights", "pa", "economic"]) {
        const q = { ...p, policy, densities: true, path: true, incomeSort: "threshold" }, data = M.run(q);
        sandbox.plots.render(data, q);
        sandbox.plots.render(data, { ...q, view: "actors", logIncome: true, incomeSort: "total" });
        const hit = sandbox.plots.hit(nodes.incomeCanvas, width / 2);
        assert.ok(hit.title.includes("Actor"));
    }
    const q = { ...p, policy: "access", scan: true, scanPoints: 8 };
    sandbox.plots.render(M.run(q), q);
    sandbox.plots.scatter(canvas(width, 240), M.causalPopulation(p, M.causalDefaults), { causal: true });
}
assert.ok(drawCalls > 10000);
console.log(`Plot geometry passed at four widths (${drawCalls} checked drawing operations).`);
