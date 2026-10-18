# Reproducing the Model and Paper

Use the repository root as the working directory. The recorded Julia
environment is 1.12.5; `Manifest.toml` records the full dependency graph.
The initial package installation can take substantially longer than later runs.

## 1. Verify the Scientific Package

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
```

The tests cover distribution dependencies, finite-population geometry, state
bounds, zero-regulation limits, rights allocations, market accounting, and
protected-area equations. The current test suite is not a proof that every
parameter combination converges. Inspect convergence for each study.

## 2. Rebuild the Main Figures

```sh
bash manuscript/generate_figures.sh
```

This runs `manuscript/figure1.jl` through `figure4.jl` and writes
`manuscript/figures/figure1.pdf` through `figure4.pdf`, with PNG counterparts.
Each script can also be run independently with `julia --project=.`.
Shared typography is in `manuscript/helpers/figure_style.jl`; Figure 3 also
exposes its panel-specific sizes as constants at the top of its script.

To refresh embedded images in the editable manuscript, use a Python environment
with the declared dependencies. This is optional for model and figure use:

```sh
python3 -m pip install -r manuscript/requirements.txt
python3 manuscript/update_figure_embeds.py
```

That script updates the current DOCX. Exporting the DOCX to PDF is a separate
Word-compatible typesetting step; regenerating images alone does not update
`manuscript/Science_MS_compact.pdf`.

## 3. Rebuild the Supplement and Numerical Records

```sh
julia --project=. SupplementaryMaterial/scripts/generate_figures.jl
julia --project=. SupplementaryMaterial/scripts/generate_reproducibility_outputs.jl
```

The second command writes the machine-readable verification table in
`SupplementaryMaterial/results/`, including quota balance, price, and solver
diagnostics. With a LaTeX installation, compile from the supplement directory:

```sh
latexmk -cd -pdf -interaction=nonstopmode -halt-on-error SupplementaryMaterial/SED_Supplementary_Material.tex
```

## 4. Verify the Browser Companion

Node.js 22 or newer is sufficient for the build and numerical checks:

```sh
node webapp/build.mjs
node webapp/test/model.test.cjs
node webapp/test/plots.test.cjs
JULIA="$(command -v julia)" node webapp/test/model.test.cjs
```

The last command additionally compares seven fixed-population browser cases
against the local Julia package. For real browser checks:

```sh
npm ci --prefix webapp
npm exec --prefix webapp -- playwright install chromium
node webapp/test/ui.test.cjs
```

Screenshots and diagnostics go to ignored `tmp/companion/`. Inspect them:
numerical tests and finite canvas coordinates do not verify typography or
layout. The CI workflow runs the Julia tests, JavaScript tests, parity checks,
and browser checks on a clean GitHub runner.

## Before Freezing a Release

- Use the same realized actors for open access and policy comparisons.
- Record `git rev-parse HEAD`, `git status --short`, Julia version, and seeds.
- Verify resource balance, projected actor derivatives, and market convergence.
- Inspect all final PDFs at their intended publication size.
- Resolve the Figure 4 impact-only "gear subsidy" interpretation before citing
  it as a literal efficiency intervention. The supplement explains the
  distinction; the companion applies the coupled dimensional transformation.
- Commit the complete sources and outputs, then tag the exact submission
  release and archive it. Do not cite an earlier commit for uncommitted work.
- Add the final paper citation and archived software DOI to `CITATION.cff`.
