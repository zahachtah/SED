# Supplementary Material

This directory contains the complete, current supplementary material for:

> *Who exits, who extracts, who gains: A distributional geometry for governing
> the commons*

## Build

Generate the supplementary figures from the repository root:

```bash
julia --project=. SupplementaryMaterial/scripts/generate_figures.jl
julia --project=. SupplementaryMaterial/scripts/generate_reproducibility_outputs.jl
```

Compile the supplement:

```bash
cd SupplementaryMaterial
latexmk -pdf -interaction=nonstopmode -halt-on-error SED_Supplementary_Material.tex
```

The compiled document is `SED_Supplementary_Material.pdf`.

## Structure

- `SED_Supplementary_Material.tex`: document entry point and linked contents.
- `sections/`: the eight active supplementary sections, in reading order.
- `figures/`: generated publication figures used by `SED_Supplementary_Material.tex`.
- `results/`: generated machine-readable endpoint checks and the compact
  verification table included in the supplement.
- `reproducibility/`: the frozen numerical-source archive, its SHA-256
  checksum, and a file-level manifest identifying the source snapshot cited
  in Section S8.1.
- `scripts/generate_figures.jl`: reproducible CairoMakie figure generator.
- `scripts/generate_reproducibility_outputs.jl`: reruns the main figure
  scenarios and records endpoints, solver status, and market diagnostics.
- `scripts/generate_empirical_mapping.jl`: the illustrative actor-level
  dependency map linking social attributes to dimensional and relational model
  quantities; it can also be run independently.
- `scripts/generate_policy_explainers.jl`: four matched, simulation-backed
  explainers for exclusive rights, tradable rights, protected areas, and
  economic instruments; it can also be run independently.
- `scripts/generate_identity_figure.jl`: a separate, explicitly illustrative
  nonlinear identity mechanism with analytic responses and simulated endpoint
  checks. This does not change the baseline model or main-text simulations.

## Frozen Numerical Source

The 2026-11-19 archive captures the model, Julia tests, dependency lockfiles,
paper and supplementary figure generators, and reference numerical tables.
It includes scientific-code changes beyond the base Git commit `a12ddaa`;
that commit alone is not the source version used by the current supplement.
The full content identifier, base commit, and per-file SHA-256 hashes are
recorded in `reproducibility/source_manifest.json`.

To verify and use the snapshot, starting from this directory:

```bash
cd reproducibility
shasum -a 256 -c SED_numerical_source_2026-11-19.tar.gz.sha256
tar -xzf SED_numerical_source_2026-11-19.tar.gz
cd SED_numerical_source_2026-11-19
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
```

The archive includes its own numerical-reproduction instructions. Manuscript
prose, rendered figures, the companion website, and installed Julia package
dependencies are deliberately not duplicated in this small source archive.

Superseded drafts and outputs may be retained locally in the ignored
`archive/` directory; they are not part of the shared supplement.

The main manuscript is the notation and scientific source of truth. Current
paper notation uses dimensional stock \(x\), exit threshold \(\theta_i\),
impact potential \(\bar u_i\), dimensional response coefficient \(a_i\), and
nondimensional response rate \(\alpha_i\).
