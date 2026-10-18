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

- `SED_Supplementary_Material.tex`: document entry point and notation guide.
- `sections/`: the eight active supplementary sections, in reading order.
- `figures/`: generated publication figures used by `SED_Supplementary_Material.tex`.
- `results/`: generated machine-readable endpoint checks and the compact
  verification table included in the supplement.
- `scripts/generate_figures.jl`: reproducible CairoMakie figure generator.
- `scripts/generate_reproducibility_outputs.jl`: reruns the main figure
  scenarios and records endpoints, solver status, and market diagnostics.
- `scripts/generate_empirical_mapping.jl`: the illustrative actor-level
  dependency map linking social attributes to dimensional and relational model
  quantities; it can also be run independently.
- `scripts/generate_policy_explainers.jl`: four matched, simulation-backed
  explainers for exclusive rights, tradable rights, protected areas, and
  economic instruments; it can also be run independently.

Superseded drafts and outputs may be retained locally in the ignored
`archive/` directory; they are not part of the shared supplement.

The main manuscript is the notation and scientific source of truth. Current
paper notation uses dimensional stock \(x\), exit threshold \(\theta_i\),
impact potential \(\bar u_i\), dimensional response coefficient \(a_i\), and
nondimensional response rate \(\alpha_i\).
