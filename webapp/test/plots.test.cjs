const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const M = require("../model.js");

// Check numeric drawing geometry at narrow and wide sizes without a browser.
// Real typography and layout still require the Playwright visual checks.
let drawCalls = 0;
const labels = [];
const rectangles = [];
let recordRectangles = false;
function context() {
    const noop = () => {};
    const finite = (...args) => { args.forEach(v => assert.ok(Number.isFinite(v))); drawCalls++; };
    return { save: noop, restore: noop, beginPath: noop, stroke: noop, fill: noop,
        clip: noop, rotate: finite, translate: finite, setTransform: finite,
        setLineDash: xs => xs.forEach(v => assert.ok(Number.isFinite(v))),
        moveTo: finite, lineTo: finite, rect: finite,
        fillRect(...args) {
            finite(...args);
            if (recordRectangles) rectangles.push({ ink: this.fillStyle, args });
        },
        arc: (x, y, r, a, b) => { finite(x, y, r, a, b); assert.ok(r >= 0); },
        fillText: (text, x, y) => { assert.equal(typeof text, "string"); labels.push(text); finite(x, y); },
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
const mismatchedRanks = {
    open: { actors: [{ id: 8, total: 20 }, { id: 3, total: 5 }, { id: 11, total: 12 }] },
    policy: { actors: [{ id: 3, total: 15 }, { id: 8, total: 7 }, { id: 11, total: 12 }] }
};
const paired = sandbox.plots.incomeRows(mismatchedRanks, { incomeSort: "total" });
assert.deepEqual(Array.from(paired, a => [a.id, a.openTotal, a.incomeChange]), [[8, 20, -13], [11, 12, 0], [3, 5, 10]]);
assert.throws(() => sandbox.plots.incomeRows({ ...mismatchedRanks, open: { actors: [] } }, { incomeSort: "total" }), /Missing open-access income/);
const convergedRows = [0, .2, .8, .95].map(strength => ({ strength, result: { converged: true } }));
const optimum = (values, minimize = false, rows = convergedRows) => sandbox.plots.scanExtremum(rows, values, minimize);
assert.deepEqual(Array.from(optimum([1, 4, 2, 3]).indices), [1]);
assert.equal(optimum([1, 4, 2, 3]).value, 4);
assert.deepEqual(Array.from(optimum([.5, .1, .3, .2], true).indices), [1]);
assert.deepEqual(Array.from(optimum([-5, -2, -3, -4]).indices), [1]);
assert.deepEqual(Array.from(optimum([2, 2, 1, 2]).indices), [0, 1, 3]);
assert.equal(optimum([2, 2, 2, 2]).flat, true);
assert.deepEqual(Array.from(optimum([null, NaN, .4, undefined], true).indices), [2]);
assert.equal(optimum([null, NaN, Infinity, undefined]), null);
const unconverged = convergedRows.map((r, i) => ({ ...r, result: { converged: i !== 1 } }));
assert.deepEqual(Array.from(optimum([1, 100, 4, 3], false, unconverged).indices), [2]);
assert.deepEqual(Array.from(optimum([.5, 0, .2, .3], true, unconverged).indices), [2]);
assert.equal(optimum([1, 2, 3, 4], false, convergedRows.map(r => ({ ...r, result: { converged: false } }))), null);
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
        for (const incomeSort of ["total", "threshold", "impact", "use", "group"]) {
            for (const logIncome of [false, true]) {
                const params = { ...q, incomeView: "change", incomeSort, logIncome };
                sandbox.plots.render(data, params);
                const rows = sandbox.plots.incomeRows(data, params);
                const openMap = new Map(data.open.actors.map(a => [a.id, a.total]));
                rows.forEach(a => assert.equal(a.incomeChange, a.total - openMap.get(a.id)));
                assert.ok(Math.abs(rows.reduce((s, a) => s + a.incomeChange, 0) - (data.policy.total - data.open.total)) < 1e-10);
                if (policy === "none") assert.ok(rows.every(a => a.incomeChange === 0));
                const changeHit = sandbox.plots.hit(nodes.incomeCanvas, width / 2);
                assert.deepEqual(Array.from(changeHit.values, ([name]) => name), ["Open-access income", "Policy income", "Income change", "Exit threshold"]);
                const deltaGini = data.policy.inequality - data.open.inequality;
                const expected = Math.abs(deltaGini) < 1e-12 ? "0" : `${deltaGini > 0 ? "+" : ""}${sandbox.plots.fmt(deltaGini)}`;
                assert.ok(labels.at(-1).endsWith(`Δ ${expected}`));
            }
        }
    }
    const q = { ...p, policy: "access", scan: true, scanPoints: 8 };
    sandbox.plots.render(M.run(q), q);
    sandbox.plots.scatter(canvas(width, 240), M.causalPopulation(p, M.causalDefaults), { causal: true });
}
const reference = M.run(p), scanParams = { ...p, policy: "access", scan: true };
// A partially active actor earns outside income as well as recovering an
// opportunity cost within harvest revenue. Negative transient rent is visible.
const componentActors = [
    { id: 0, effectiveTheta: .2, resource: 5, wages: 4, outsideOnly: 6, total: 9, trade: 0 },
    { id: 1, effectiveTheta: .3, resource: 1, wages: 4, outsideOnly: 6, total: 5, trade: 0 },
    { id: 2, effectiveTheta: .4, resource: 0, wages: 6, outsideOnly: 6, total: 6, trade: 0 }
];
const componentResult = { ...reference.open, actors: componentActors };
nodes.phaseCanvas = canvas(900, 330);
nodes.incomeCanvas = canvas(900, 250);
recordRectangles = true;
sandbox.plots.render({ ...reference, open: componentResult, policy: componentResult },
    { ...p, path: false, densities: false, incomeSort: "threshold" });
recordRectangles = false;
const componentBars = ink => rectangles.filter(r => r.ink === ink);
const outsideBars = componentBars(palette.alternative);
const opportunityBars = componentBars(palette.opportunity);
const rentBars = componentBars(palette.rent);
assert.equal(outsideBars.length, 3);
assert.equal(opportunityBars.length, 3);
assert.equal(rentBars.length, 3);
const unitHeight = outsideBars[0].args[3] / 4;
for (const [bars, values] of [[outsideBars, [4, 4, 6]], [opportunityBars, [2, 2, 0]], [rentBars, [3, 1, 0]]]) {
    bars.forEach((bar, i) => assert.ok(Math.abs(bar.args[3] / unitHeight - values[i]) < 1e-10));
}
assert.ok(Math.abs(rentBars[1].args[1] - opportunityBars[1].args[1]) < 1e-10);
const scan = convergedRows.map((r, i) => ({ ...r, result: { ...reference.open, converged: true,
    y: [.1, .8, .3, .2][i], participation: .4, resourceRent: [1, 2, 4, 3][i],
    total: [-5, -2, -3, -4][i], inequality: [.6, .2, .4, .3][i] } }));
nodes.phaseCanvas = canvas(900, 330);
nodes.incomeCanvas = canvas(900, 250);
labels.length = 0;
sandbox.plots.render({ ...reference, scan }, scanParams);
assert.ok(labels.includes("Max 0.80 · 20%"));
assert.ok(labels.includes("Min 0.20 · 20%"));
assert.ok(labels.includes("Max -2.00 · 20%"));
assert.ok(labels.includes("Max 4.00 · 80%"));
assert.ok(labels.includes("Constant 0.40"));
const giniHit = sandbox.plots.hit(nodes.incomeCanvas, 300 + 36 + .2 * 249, 190);
assert.equal(giniHit.title, "Gini");
assert.deepEqual(Array.from(giniHit.values, pair => Array.from(pair)), [
    ["Policy strength", "20%"], ["Value", "0.20"], ["Converged", "Yes"],
    ["Minimum sampled", "0.20"], ["At policy strength", "20%"]
]);
assert.equal(sandbox.plots.hit(nodes.incomeCanvas, 310, 140), null);
assert.equal(sandbox.plots.hit(nodes.incomeCanvas, 100, 500), null);
labels.length = 0;
sandbox.plots.render({ ...reference, scan: scan.map(r => ({ ...r, result: { ...r.result, converged: false } })) }, scanParams);
assert.equal(labels.filter(text => text === "No converged points").length, 6);
assert.ok(drawCalls > 10000);
console.log(`Income levels/changes, scan maxima/Gini minima, convergence, ties, tooltips, and plot geometry passed at four widths (${drawCalls} drawing checks).`);
