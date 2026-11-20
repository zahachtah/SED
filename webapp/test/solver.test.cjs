const assert = require("node:assert/strict");
const M = require("../model.js");
const reference = require("./fixtures/solver-reference.cjs");

const cases = [
    {}, { policy: "access", selector: "low", exclusion: .36 },
    { policy: "access", selector: "random", exclusion: .7 },
    { policy: "rights", quota: .25 },
    { policy: "rights", quota: .4, historical: true },
    { policy: "rights", target: "yield", quota: .1 },
    { policy: "rights", target: "yield", quota: .18, historical: true },
    { policy: "pa", protected: .5, mobility: .3 },
    { policy: "pa", protected: .3, mobility: 0, tourism: .2 },
    { policy: "economic", gear: .5, royalty: .2 },
    { policy: "economic", royalty: 0, gear: -.5, effort: .3, outside: .2 },
    { meanTheta: 0, thetaSpread: 0, totalImpact: 1.4 },
    { meanTheta: 0, totalImpact: .4 }, { thetaSpread: 0 },
    { thresholdSampling: "random", impactSampling: "random", correlation: -.9 },
    { populationMode: "causal" },
    { solver: "euler", n: 16, policy: "rights", quota: .5 },
    { solver: "euler", n: 16, policy: "pa", protected: .3, mobility: .2 },
    { n: 1000, policy: "rights", target: "yield", quota: .1 }
];
for (const change of cases) {
    const p = { ...M.defaults, n: 64, ...change }, base = M.population(p), oa = { ...p, policy: "none" };
    const before = reference(base, oa), after = M.solve(base, oa);
    const legacy = (actual, expected) => Object.fromEntries(Object.keys(expected).map(key => [key,
        key === "actors" ? actual.actors.map((a, i) => legacy(a, expected.actors[i])) : actual[key]]));
    assert.deepEqual(legacy(after, before), before, `Open-access states, paths, and steps: ${JSON.stringify(change)}`);
    // A catchability intervention preserves physical initial effort, so its
    // pressure-unit initial state must change by the catchability multiplier.
    const g = M.policyActive(p) && p.policy === "economic" ? 1 + p.gear : 1;
    const initial = g === 1 ? before : { ...before, state: before.state.map((u, i) => i < base.length ? g * u : u) };
    const actual = M.solve(base, p, after), expected = reference(base, p, initial);
    expected.policyImpact = actual.actors.reduce((s, a, i) => s + Math.abs(a.use - before.state[i]), 0);
    assert.deepEqual(legacy(actual, expected), expected,
        `Policy states, paths, steps, and income: ${JSON.stringify(change)}`);
}

const p = { ...M.defaults, n: 64 }, session = M.createSession();
const initial = session.run(p);
const rights = session.run({ ...p, policy: "rights", quota: .25 });
const historical = session.run({ ...p, policy: "rights", quota: .4, historical: true });
assert.equal(rights.open, initial.open);
assert.equal(historical.open, initial.open);
assert.deepEqual(rights.policy, M.run({ ...p, policy: "rights", quota: .25 }).policy);
const newPopulation = session.run({ ...p, meanTheta: .7 });
assert.notEqual(newPopulation.open, initial.open);
assert.deepEqual(newPopulation, M.run({ ...p, meanTheta: .7 }));
const seeded = M.createSession().run({ ...p, policy: "access" }, initial.open);
assert.equal(seeded.open, initial.open);
const fields = { n: 32, seed: 4, alpha: .02, solver: "euler", thresholdSampling: "random", impactSampling: "random",
    meanTheta: .6, thetaSpread: 1, totalImpact: 2, impactSpread: 1, correlation: .6,
    populationMode: "causal", causal: M.causalDefaults, records: [{ theta: .3, potential: 1 }] };
for (const [key, value] of Object.entries(fields)) assert.notEqual(M.populationKey(p), M.populationKey({ ...p, [key]: value }), key);
assert.equal(M.populationKey(p), M.populationKey({ ...p, policy: "rights", quota: .1, incomeView: "change" }));
console.log(`Legacy solver outputs match the reference for ${cases.length} scenarios with the corrected physical-effort gear initialization; session reuse/invalidation passed.`);
