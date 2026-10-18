# SED Research Companion

Open [`../index.html`](../index.html)
in a browser. It is a self-contained HTML document with local computation,
bundled Lucide icons, and no runtime CDN, account, analytics, or server.
The same file can be hosted on any static website, including GitHub Pages.

The first view exposes population distributions, policy instruments, resource
balance, and income outcomes. Examples and a guided tour explain the geometry.
The population-builder drawer derives joint thresholds and impact potentials
from illustrative health, gendered-access, care, and capital pathways. Export
scenario JSON and actor CSV records to retain a reproducible exploration.

## Source Files

- `index.html`: semantic interface and population-builder drawer.
- `companion.css`: desktop, mobile, light, dark, and print styles.
- `model.js`: sampling, dimensional pathways, policies, projected RK23/Euler,
  equilibrium curves, income accounting, and policy scans.
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
node webapp/test/plots.test.cjs
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
`--pages` stages only the companion and its two reading PDFs in `tmp/pages/`.
