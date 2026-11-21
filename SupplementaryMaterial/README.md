# Supplementary Numerical Source

**Supplementary material (pending approval).** The document PDF, LaTeX prose,
rendered figures, verification outputs and frozen submission archive are not
distributed at present. Author copies are retained locally in the ignored
archive. Do not restore them to Git without approval.

The public `scripts/` directory retains the numerical and figure-generation
code, including helpers exercised by the Julia regression tests:

- `generate_figures.jl`: supplementary CairoMakie figures.
- `generate_reproducibility_outputs.jl`: main-scenario endpoint, income,
  solver and market checks.
- `generate_empirical_mapping.jl`: illustrative links from social attributes
  to dimensional and relational quantities.
- `generate_policy_explainers.jl`: exclusive rights, tradable rights,
  protected areas and economic instruments.
- `generate_identity_figure.jl` and `identity_extension.jl`: an explicitly
  illustrative nonlinear identity mechanism, separate from the baseline model.

Run the generators from the repository root:

```sh
julia --project=. SupplementaryMaterial/scripts/generate_figures.jl
julia --project=. SupplementaryMaterial/scripts/generate_reproducibility_outputs.jl
```

Generated figures and results are local, ignored outputs. The unpublished
LaTeX document is not required to run the Julia model or browser companions.
