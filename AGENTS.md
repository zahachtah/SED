# Repository Guidelines

## Project Structure & Modules
- `Project.toml` / `Manifest.toml`: Julia environment and locked dependencies.
- `SEDist.jl`: Lightweight module that re-exports plotting utils and exports the public API.
- `SEDist_selfcontained.jl`: Core SED types, ODE model (`sim`), income/metrics, and plotting helpers.
- Analysis scripts: `U_W_cov_analysis.jl`, `CausalGraphTest.jl` (usage examples and figures).
- Assets & docs: `figure6.png`, `readme.md`, `todo.md`.

## Setup, Run, and Development
- Install deps: `julia --project -e 'using Pkg; Pkg.instantiate()'`.
- Work in REPL: `julia --project` then `include("SEDist.jl"); using .SEDist`.
- Run examples:
  - `julia --project -e 'include("U_W_cov_analysis.jl"); qwcovar()'`.
  - `julia --project -e 'include("CausalGraphTest.jl")'`.
- Plotting: if headless or to force raster, `using CairoMakie; CairoMakie.activate!()`.

## Coding Style & Naming
- Indentation: 4 spaces; keep lines readable and functions small.
- Modules `CamelCase`; functions and variables `lowercase_with_underscores`.
- Unicode identifiers are used (e.g., `γ`, `μ`, `ϕ`, `w̃`, `ū`); keep and document them in docstrings.
- Public API lives in `SEDist.jl` exports; avoid unexported cross-file globals.

## Testing Guidelines
- No formal test suite yet. Add tests under `test/` with `test/runtests.jl`.
- Use `Test`: `using Test; @test ...`. Name files by feature (e.g., `test/sed_generation.jl`).
- Run tests: `julia --project -e 'using Pkg; Pkg.test()'`.
- For scripts, add lightweight assertions to catch regressions.

## Commit & PR Guidelines
- Commits: imperative, concise, describe intent (e.g., "Add μ/γ dependency handling").
- PRs: clear summary, what/why, minimal repro (commands), and plots/screenshots when visuals change.
- Link related issues, update `readme.md`/examples when APIs or outputs change.
- Keep diffs focused; avoid committing large binaries—link or generate on demand.

## Security & Configuration
- Reproducibility: respect `Manifest.toml`; bump deps via a dedicated PR.
- Performance: set `JULIA_NUM_THREADS` as needed for simulations.
- Secrets: do not embed credentials in scripts or notebooks.

