/* Keep idle workers warm; cancel in-flight simulations instead of queuing stale work. */
function createSEDRunner(options) {
    "use strict";
    const { model = SEDModel, workerFactory = null } = options || {};
    const fallback = model.createSession();
    let worker = null, pending = null, serial = 0, source = null;
    const stop = () => { worker?.terminate(); worker = null; };
    const spawn = workerFactory || (() => {
        source ||= `const M=(${createSEDModel.toString()})();const session=M.createSession();onmessage=e=>{const {id,p,open}=e.data;try{const data=session.run(p,open,s=>postMessage({id,progress:s}));postMessage({id,data});}catch(error){postMessage({id,error:error.message});}};`;
        const url = URL.createObjectURL(new Blob([source], { type: "application/javascript" }));
        try { return new Worker(url); } finally { URL.revokeObjectURL(url); }
    });
    const finish = (request, error, data) => {
        if (pending !== request) return;
        pending = null;
        if (error) request.reject(error); else request.resolve(data);
    };
    const runFallback = request => {
        if (pending !== request) return;
        stop();
        request.onProgress?.({ stage: "fallback" });
        setTimeout(() => {
            if (pending !== request) return;
            try { finish(request, null, fallback.run(request.p, request.open, request.onProgress)); }
            catch (error) { finish(request, error); }
        }, 0);
    };
    const cancel = () => {
        if (!pending) return;
        const request = pending;
        pending = null;
        stop();
        request.resolve(null);
    };
    const run = (p, open = null, onProgress = null) => {
        cancel();
        return new Promise((resolve, reject) => {
            const request = { id: ++serial, p, open, onProgress, resolve, reject };
            pending = request;
            try {
                const fresh = !worker;
                if (fresh) {
                    const created = spawn();
                    worker = created;
                    created.onmessage = event => {
                        const current = pending;
                        if (worker !== created || !current || event.data.id !== current.id) return;
                        if (event.data.error) finish(current, new Error(event.data.error));
                        else if (event.data.progress) current.onProgress?.(event.data.progress);
                        else if (event.data.data) finish(current, null, event.data.data);
                    };
                    created.onerror = () => {
                        if (worker !== created) return;
                        if (pending) runFallback(pending); else stop();
                    };
                }
                // The first request can seed a replacement worker; later requests
                // use its private cache without cloning open-access actors or paths.
                worker.postMessage({ id: request.id, p, ...(fresh ? { open } : {}) });
            } catch (error) { runFallback(request); }
        });
    };
    return { run, cancel, dispose() { cancel(); stop(); } };
}

if (typeof module !== "undefined") module.exports = createSEDRunner;
