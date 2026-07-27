# Supplementary Material

This directory contains the complete, current supplementary material for:

> *Who exits, who extracts, who gains: A distributional geometry for governing
> the commons*

## Build

Generate the supplementary figures from the repository root:

```bash
julia --project=. SupplementaryMaterial/scripts/generate_figures.jl
```

Compile the supplement:

```bash
cd SupplementaryMaterial
latexmk -pdf -interaction=nonstopmode -halt-on-error main.tex
```

The compiled document is `main.pdf`.

## Structure

- `main.tex`: document entry point and notation guide.
- `sections/`: the six active supplementary sections, in reading order.
- `figures/`: generated publication figures used by `main.tex`.
- `scripts/generate_figures.jl`: reproducible CairoMakie figure generator.
- `AUDIT.md`: manuscript-to-supplement consistency audit.

Superseded drafts and outputs may be retained locally in the ignored
`archive/` directory; they are not part of the shared supplement.

The main manuscript is the notation and scientific source of truth. Current
paper notation uses dimensional stock \(x\), exit threshold \(\theta_i\),
impact potential \(\bar u_i\), dimensional response coefficient \(a_i\), and
nondimensional response rate \(\alpha_i\).
