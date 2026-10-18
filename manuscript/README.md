# Manuscript and Main Figures

- [Current manuscript PDF](Science_MS_compact.pdf)
- [Editable manuscript](Science_MS_compact.docx)

There is one maintained script and one numbered PDF/PNG pair per main figure.

| Figure | Script | Output |
| --- | --- | --- |
| 1: Exit readiness | [figure1.jl](figure1.jl) | [figure1.pdf](figures/figure1.pdf) |
| 2: From heterogeneity to outcomes | [figure2.jl](figure2.jl) | [figure2.pdf](figures/figure2.pdf) |
| 3: Distributional mechanisms | [figure3.jl](figure3.jl) | [figure3.pdf](figures/figure3.pdf) |
| 4: Policy instruments | [figure4.jl](figure4.jl) | [figure4.pdf](figures/figure4.pdf) |

From the repository root:

```sh
bash manuscript/generate_figures.sh
```

The `helpers/` directory holds shared figure typography and the fixed policy
populations used by Figure 4 and the numerical verification tables. It is not
a second model implementation: population curves call the Julia package.

See the [reproduction guide](../docs/reproducibility.md) for environment setup,
optional DOCX image updates, and supplementary figures. Superseded drafts and
visual alternatives are not part of the public tree.
