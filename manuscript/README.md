# Main-Figure Source Code

**Manuscript (pending approval).** The manuscript, combined PDF, and rendered
submission figures are not distributed at present. Author copies are retained
locally in the ignored archive. Do not restore them to Git without approval.

## Reproduce the Figures

| Figure | Script |
| --- | --- |
| 1: Exit readiness | [figure1.jl](figure1.jl) |
| 2: From heterogeneity to outcomes | [figure2.jl](figure2.jl) |
| 3: Distributional mechanisms | [figure3.jl](figure3.jl) |
| 4: Policy instruments | [figure4.jl](figure4.jl) |

From the repository root:

```sh
bash manuscript/generate_figures.sh
```

Each script also runs independently with `julia --project=.` and writes a
PDF/PNG pair to `figures/`. Shared typography is in
[`helpers/figure_style.jl`](helpers/figure_style.jl); Figure 4 populations and
geometry are in [`helpers/policy_scenarios.jl`](helpers/policy_scenarios.jl).
These helpers use the Julia package rather than a separate numerical model.

Generated PDFs and PNGs stay local and are ignored by Git pending approval.
The [reproduction guide](../docs/reproducibility.md) explains the software
environment and numerical verification records.

## Figure 4 Accounting

The primary Figure 4 shows income levels, with all eight income panels using
one vertical scale, including negative rights payments. Actors are ordered by
their exit thresholds. `figure4(income_scale=:policy)` instead links scales
within each policy row.

Resource rent is retained harvest revenue minus forgone outside earnings,
before rights transfers. Total actor income includes outside earnings and net
rights transfers but excludes government royalty receipts. Literal gear support
changes both impact potentials and exit thresholds. Income components and
solver/market diagnostics can be regenerated locally with
`SupplementaryMaterial/scripts/generate_reproducibility_outputs.jl`.

## Income-Change Alternative

The retained alternative does not overwrite the primary Figure 4:

```sh
julia --project=. manuscript/incomedifferenceonlyFig4.jl
```

[`incomedifferenceonlyFig4.jl`](incomedifferenceonlyFig4.jl) writes a local PDF
and PNG. It shows each actor's policy-minus-open-access income in the
original threshold order, on a shared symmetric scale. Blue marks gains and red
losses. Gini changes are calculated from the two income-level distributions,
not from signed income changes. Generated component differences and rendered
outputs are ignored by Git pending publication approval.
