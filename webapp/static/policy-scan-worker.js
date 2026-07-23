import { scanPolicySet } from "./model.js";

self.onmessage = (event) => {
  const { spec, resolution } = event.data;
  try {
    const results = scanPolicySet(spec, { resolution });
    self.postMessage({ ok: true, results });
  } catch (error) {
    self.postMessage({ ok: false, error: error.message || String(error) });
  }
};
