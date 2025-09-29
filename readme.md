# SED — Socio‑economic/Social‑ecological Distributions

SED provides simple, composable distributions for agents and resources, plus simulation and plotting helpers for socio‑ecological models. It’s lightweight by default (core only), with plotting functions available when Makie is present.

Quick Start (core)

```julia
include("SED.jl"); using .SED

N = 100
s = (
  N = N,
  q = dist(min=1/N, max=1/N, normalize=true),
  w = dist(min=0.2, max=0.4),
  K = 2.0,
  # deps inferred from the string; `sed` is the base vector
  w̃ = dist(min=0.1, max=1.0, dependency_fun = "q .* w ./ K .+ sed"),
  ū  = dist(dependency_fun = "q ./ w̃"),
)
sample!(s)   # resolves dependencies topologically

sol = sim(scenario(base(N=N); w̃=dist(data=s.w̃), ū=dist(data=s.ū)))
```

Dependent Distributions

- Function form (explicit deps):
  `dist(dependent=(:q,:w,:K), dependency_fun=(indep,dep)->dep.q .* dep.w ./ dep.K .+ indep)`
- String form (deps inferred):
  `dist(dependency_fun="q .* w ./ K .+ sed")`
- Shorthand rewrite: strings like `1-gender*sed` auto‑broadcast to `1 .- gender .* sed`.

Plotting (optional)

```julia
import CairoMakie; CairoMakie.activate!()  # any Makie backend works
fig = Figure(); ax = Axis(fig[1,1]); phase_plot!(ax, sol); display(fig)
gfig = dependency_graph_plot(s); display(gfig)
```

Reproducible Figures

- Manuscript figures: `julia --project manuscript/figures.jl` → `manuscript/figures`.
- README figures: `julia --project examples/readme_figures.jl` → `examples/figures`.

sample! Overrides

```julia
sample!(s, :q; N=50)       # realize one param at length 50
sample!(s; N=50)           # whole context at length 50
sample!(s; random=true)    # force random sampling for this call
```

Core API

- `dist`, `sample!` (per Dist, per param, whole context; `N`, `random` overrides)
- `scenario`, `base`/`high_impact`/`low_impact`/`high_incentives`
- `sim`, `incomes`, `gini`, `regulation_scan`, `dependency_graph`

Plotting API (loads when Makie is available)

- `phase_plot!`, `phase_plot`, `incomes_plot!`, `dependency_graph_plot`
- Components: `Γ_plot!`, `Φ_plot!`, `attractor_plot!`, `trajecory_plot!`, `bg_plot!`, `target_plot!`
