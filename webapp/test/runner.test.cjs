const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { Worker } = require("node:worker_threads");
const M = require("../model.js");
const createRunner = require("../runner.js");

(async () => {
    const workers = [], urls = new Map();
    let createdURLs = 0, revokedURLs = 0;
    class WorkerAdapter {
        constructor(url) {
            this.messages = [];
            this.terminated = false;
            const bridge = `const {parentPort}=require("node:worker_threads");globalThis.postMessage=data=>parentPort.postMessage(data);parentPort.on("message",data=>globalThis.onmessage({data}));\n`;
            this.thread = new Worker(bridge + urls.get(url), { eval: true });
            this.thread.on("message", data => this.onmessage?.({ data }));
            this.thread.on("error", error => this.onerror?.(error));
            this.exited = new Promise(resolve => this.thread.once("exit", resolve));
            workers.push(this);
        }
        postMessage(message) { this.messages.push(structuredClone(message)); this.thread.postMessage(message); }
        terminate() { this.terminated = true; this.thread.terminate(); }
    }
    const sandbox = { Worker: WorkerAdapter, setTimeout,
        Blob: class { constructor(parts) { this.source = parts.join(""); } },
        URL: { createObjectURL(blob) { const id = `blob:${++createdURLs}`; urls.set(id, blob.source); return id; },
            revokeObjectURL(id) { urls.delete(id); revokedURLs++; } } };
    vm.createContext(sandbox);
    for (const name of ["model.js", "runner.js"]) vm.runInContext(fs.readFileSync(path.join(__dirname, "..", name), "utf8"), sandbox);
    vm.runInContext("globalThis.runner=createSEDRunner();", sandbox);
    const runner = sandbox.runner, p = { ...M.defaults, n: 64 };
    try {
        const first = await runner.run(p);
        assert.deepEqual(first, M.run(p));
        const q = { ...p, policy: "rights", quota: .25 };
        const second = await runner.run(q, first.open);
        assert.deepEqual(second, M.run(q, first.open));
        assert.equal(workers.length, 1, "completed simulations reuse the worker");
        assert.ok(Object.hasOwn(workers[0].messages[0], "open"));
        assert.ok(!Object.hasOwn(workers[0].messages[1], "open"), "reuse avoids sending the open-access result again");
        runner.cancel();
        assert.equal(workers[0].terminated, false, "cancel leaves an idle worker warm");
        const changed = { ...q, meanTheta: .6 };
        assert.deepEqual(await runner.run(changed), M.run(changed), "population changes invalidate the worker cache");
        const obsolete = runner.run({ ...q, scan: true, scanPoints: 64 }, first.open);
        runner.cancel();
        assert.equal(await obsolete, null);
        assert.equal(workers[0].terminated, true, "in-flight work is terminated rather than queued");
        const replacement = await runner.run(q, first.open);
        assert.deepEqual(replacement, second);
        assert.equal(workers.length, 2);
        assert.deepEqual(workers[1].messages[0].open, first.open, "replacement workers are seeded with the known baseline");
        assert.equal(urls.size, 0);
        assert.equal(createdURLs, revokedURLs);
    } finally {
        runner.dispose();
        await Promise.all(workers.map(worker => worker.exited));
    }

    const controlled = [], progress = [];
    const controlledRunner = createRunner({ model: M, workerFactory: () => {
        const worker = { messages: [], postMessage(message) { this.messages.push(message); }, terminate() { this.terminated = true; } };
        controlled.push(worker);
        return worker;
    } });
    const obsolete = controlledRunner.run(p, null, value => progress.push(value));
    const latest = controlledRunner.run(p, null, value => progress.push(value));
    assert.equal(await obsolete, null);
    const firstId = controlled[0].messages[0].id, lastId = controlled[1].messages[0].id;
    controlled[0].onmessage({ data: { id: firstId, data: { stale: true } } });
    controlled[0].onmessage({ data: { id: firstId, progress: { stale: true } } });
    controlled[1].onmessage({ data: { id: lastId - 1, data: { stale: true } } });
    controlled[1].onmessage({ data: { id: lastId, progress: { stage: "policy" } } });
    controlled[1].onmessage({ data: { id: lastId, data: { current: true } } });
    assert.deepEqual(await latest, { current: true });
    assert.deepEqual(progress, [{ stage: "policy" }]);
    const failed = controlledRunner.run(p);
    const failId = controlled[1].messages.at(-1).id;
    controlled[1].onmessage({ data: { id: failId, error: "invalid simulation" } });
    await assert.rejects(failed, /invalid simulation/);
    controlledRunner.dispose();

    const fallbackProgress = [];
    const noWorker = createRunner({ model: M, workerFactory: () => { throw Error("Workers unavailable"); } });
    assert.deepEqual(await noWorker.run(p, null, value => fallbackProgress.push(value.stage)), M.run(p));
    assert.ok(fallbackProgress.includes("fallback"));
    const cancelledFallback = noWorker.run(p);
    noWorker.cancel();
    assert.equal(await cancelledFallback, null);
    noWorker.dispose();
    const brokenWorker = createRunner({ model: M, workerFactory: () => {
        const worker = { postMessage() { queueMicrotask(() => worker.onerror()); }, terminate() {} };
        return worker;
    } });
    assert.deepEqual(await brokenWorker.run(p), M.run(p));
    brokenWorker.dispose();
    const cloneFailure = createRunner({ model: M, workerFactory: () => ({ postMessage() { throw Error("Clone failed"); }, terminate() {} }) });
    assert.deepEqual(await cloneFailure.run(p), M.run(p));
    cloneFailure.dispose();
    console.log("Production worker source, reuse, cache invalidation, cancellation, stale messages, URL cleanup, errors, and fallback passed.");
})().catch(error => { console.error(error); process.exitCode = 1; });
