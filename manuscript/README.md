# Manuscript and Main Figures

- [Submission manuscript](Science_MS_compact.pdf)
- [Manuscript and supplementary material together](Norberg_Anderies_Manuscript_and_Supplement.pdf)
- [Standalone supplementary material](../SupplementaryMaterial/SED_Supplementary_Material.pdf)

The manuscript PDF is the author's typeset export of 19 November 2026. It is
the paper's scientific reference. Earlier Word drafts and editorial worklists
are retained in the local ignored archive, not distributed as competing versions.

## Reproduce the Figures

| Figure | Script | PDF |
| --- | --- | --- |
| 1: Exit readiness | [figure1.jl](figure1.jl) | [figure1.pdf](figures/figure1.pdf) |
| 2: From heterogeneity to outcomes | [figure2.jl](figure2.jl) | [figure2.pdf](figures/figure2.pdf) |
| 3: Distributional mechanisms | [figure3.jl](figure3.jl) | [figure3.pdf](figures/figure3.pdf) |
| 4: Policy instruments | [figure4.jl](figure4.jl) | [figure4.pdf](figures/figure4.pdf) |

From the repository root:

```sh
bash manuscript/generate_figures.sh
```

Each script also runs independently with `julia --project=.` and writes a
PDF/PNG pair to `figures/`. Shared typography is in
[`helpers/figure_style.jl`](helpers/figure_style.jl); Figure 4 populations and
geometry are in [`helpers/policy_scenarios.jl`](helpers/policy_scenarios.jl).
These helpers use the Julia package rather than a separate numerical model.

Generating figures does not rewrite the manuscript PDF or its prose.
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
solver/market diagnostics are recorded in
[`main_figure_verification.csv`](../SupplementaryMaterial/results/main_figure_verification.csv).

## Income-Change Alternative

The retained alternative does not overwrite the primary Figure 4:

```sh
julia --project=. manuscript/incomedifferenceonlyFig4.jl
```

[`incomedifferenceonlyFig4.jl`](incomedifferenceonlyFig4.jl) writes
[`figures/incomedifferenceonlyFig4.pdf`](figures/incomedifferenceonlyFig4.pdf)
and its PNG. It shows each actor's policy-minus-open-access income in the
original threshold order, on a shared symmetric scale. Blue marks gains and red
losses. Gini changes are calculated from the two income-level distributions,
not from signed income changes. Full component differences are saved in
[`figure4_income_changes.csv`](../SupplementaryMaterial/results/figure4_income_changes.csv).
