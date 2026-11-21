# SED Research Companion

**[Open the hosted companion](https://zahachtah.github.io/SED/)**, or open
[`../index.html`](../index.html) offline in a browser.
It is a self-contained HTML document with local computation,
bundled Lucide icons, and no runtime CDN, account, analytics, or server.
The same file can be hosted on any static website, including GitHub Pages.

The first view exposes population distributions, policy instruments, resource
balance, and income outcomes. Examples and a guided tour explain the geometry.
The population-builder drawer derives joint thresholds and impact potentials
from illustrative health, gendered-access, care, and capital pathways. Export
scenario JSON and actor CSV records to retain a reproducible exploration.

The income plot switches between income levels and policy-minus-open-access
income changes, paired by actor identity before applying the selected sort.
The change view uses blue for gains, red for losses, and a zero reference;
its Gini annotation compares the two income-level distributions. Switching
views or using the symmetric log scale does not rerun the simulation.

Scan policy marks each outcome's maximum, or Gini's minimum, among converged
sampled runs. Labels give the value and policy strength; ties are marked together
and constant outcomes are identified. Hover for the sampled values. These are
discrete scan optima, not a continuous optimization between simulation points.

## Source Files

- `index.html`: semantic interface and population-builder drawer.
- `companion.css`: desktop, mobile, light, dark, and print styles.
- `model.js`: sampling, dimensional pathways, policies, projected RK23/Euler,
  equilibrium curves, income accounting, and policy scans.
- `runner.js`: reusable worker, worker-local open-access cache, cancellation,
  and the main-thread fallback.
- `plots.js`: scientific canvas plots and hit testing.
- `app.js`: controls, worker orchestration, explanations, import/export, and
  reproducible URL settings.
- `build.mjs`: assembles the distributable HTML at the repository root.
- `SCIENCE.md`: scientific assumptions, differences from the old playground,
  interpretation, and parity verification.

## Build and Check

```sh
node webapp/build.mjs
node webapp/test/model.test.cjs
node webapp/test/solver.test.cjs
node webapp/test/runner.test.cjs
node webapp/test/plots.test.cjs
node webapp/test/publication.test.cjs
JULIA="$(command -v julia)" node webapp/test/model.test.cjs
julia --project=. -e 'using Pkg; Pkg.test()'
```

The Julia parity run assumes the repository project has been instantiated.
For browser QA, install the pinned development dependencies:

```sh
npm ci --prefix webapp
npm exec --prefix webapp -- playwright install chromium
node webapp/test/ui.test.cjs
```

This opens the self-contained file, checks controls, scans, and pathway
changes, and writes desktop/mobile screenshots to ignored `tmp/companion/`.
The browser dependency is for development only; the shipped page needs none.
`npm run capture --prefix webapp` also updates the README's linked preview,
but only after those browser checks pass.

To inspect the modular source through HTTP during development:

```sh
python3 -m http.server 8000 --bind 127.0.0.1 --directory webapp
```

The shipped HTML also works directly from disk. Importing an exported scenario
restores its saved actor records exactly; the original distribution and pathway
settings remain available for returning to generated populations.
URL sharing is useful for a
hosted companion; a `file:` URL refers to the local machine. Imported actor
records are accepted as `parameters.records` with a nonnegative `theta`, a
positive `potential`, and `parameters.populationMode = "imported"`.

Lucide is bundled under its ISC license in `vendor/lucide.LICENSE`.

See the [Pages guide](../docs/github-pages.md) for the manual publication
workflow. `node webapp/build.mjs --check` checks for source/HTML drift;
`--pages` stages only the companion in `tmp/pages/`. Manuscript and
supplementary material are pending approval; no paper PDF is deployed or
required to build the website.
The publication check also verifies local documentation links and confirms that
drafts, private archives, and development files cannot enter that Pages bundle.

## Simulation Performance

Idle workers are reused, retaining the engine and open-access cache. New
physics requests cancel unfinished work rather than queuing stale simulations;
a replacement worker can be seeded with the last matching open-access run.
Policy-only updates do not send that full result back to an existing worker.
Population, solver, and response-rate changes invalidate the baseline cache.

RK23 reuses the last accepted stage derivative (including its projected state)
and the initial derivative of rejected attempts. Numeric actor data use
`Float64Array`, and convergence checks avoid temporary arrays. Equations,
stage bounds, tolerances, equilibrium checks, and plotted path samples are
unchanged. The solver regression test compares full results bit-for-bit with
the frozen pre-optimization integrator, including Euler and every policy.

Run `npm run benchmark --prefix webapp` for interleaved, warmed-up comparisons
against that reference at 320 and 1,000 actors. These are Node model timings,
not browser rendering or worker-startup measurements.

WebAssembly is not enabled. A future optional Wasm backend should keep the
complete double-precision numerical loop inside the module, reuse its memory,
preserve all projected-stage and convergence rules, and pass the same reference
and Julia parity checks before being selected. Keep a JavaScript fallback and
embed the module in the standalone build to retain offline `file:` support.
Its speed advantage must be benchmarked rather than assumed; the current
environment has no installed Wasm compiler target.
