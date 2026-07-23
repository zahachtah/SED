# Browser App

This is a frontend-only prototype for running the SED framework in the browser.

## What it does

- define causal/distributional inputs as browser-side variables
- derive `w̃` and `ū` from dependency expressions
- run the model interactively with live updates
- scan enabled policies in a Web Worker, still without any backend

## Run locally

From the repository root:

```bash
python3 -m http.server 8000
```

Then open:

```text
http://localhost:8000/webapp/static/
```

## Notes

- This version is pure JavaScript and static assets only.
- The simulation engine is a browser port of the current Julia logic, simplified for interactivity.
- Policy scans currently run in a worker on the CPU. WebGL2 capability detection and a dedicated batch-engine hook are in place so the scan kernel can move into float-texture batch execution next without changing the UI contract.
