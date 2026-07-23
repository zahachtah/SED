# SED

SED is a Julia model of how heterogeneous exit thresholds and impact potentials
shape renewable-resource use, ecological attractors, and income distributions.
It provides composable actor distributions, a bounded ODE simulation, policy
types, outcome metrics, and CairoMakie plotting helpers.

The scientific model and notation are documented in
[`docs/model-paper-crosswalk.md`](docs/model-paper-crosswalk.md). AI-assisted
study work should also follow [`AGENTS.md`](AGENTS.md).

## Install and Test

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. -e 'using Pkg; Pkg.test()'
```

## Minimal Simulation

```julia
using SED

s = base(N=300)
sample!(s; random=false)  # ordered quantiles

open_access = sim(s)

policy = scenario(
    s;
    policy=TradableUseRights(:effort, 0.05, 0.0, false),
)
with_quota = sim(policy; regulation=0.40, start_from_OA=true)
```

`regulation=0.40` means a 40% reduction from the unregulated total quota for
tradable rights, leaving aggregate rights of `0.60`.

## Custom Population

The paper uses `\Theta_i` for exit thresholds and `\bar u_i` for impact
potentials. Their current internal field names are `w̃` and `ū`.

```julia
using SED

N = 500
p = (
    N=N,
    α=0.05,
    outside_income=dist(min=0.1, max=1.0, distribution=LogNormal),
    efficiency=dist(min=0.5, max=1.5),
    w̃=dist(dependency_fun="outside_income / efficiency"),
    ū=dist(dependency_fun="efficiency", normalize=true),
    R=ones(N),
)

s = scenario(p)
sample!(s; random=true)
sol = sim(s)
```

Dependencies are resolved topologically. Use `@dependent` instead of a string
when the relationship is easier to express as Julia:

```julia
w̃ = dist(dependency=@dependent (outside_income, efficiency) ->
    outside_income ./ efficiency)
```

## Built-in Policies

```julia
scenario(s; policy=OpenAccess())
scenario(s; policy=ExclusiveUseRights(:top, false))
scenario(s; policy=TradableUseRights(:effort, 0.05, 0.0, false))
scenario(s; policy=ProtectedArea(0.3))
scenario(s; policy=EconomicIncentives([:cost], :additive))
```

See [`docs/policies.md`](docs/policies.md) before using a policy in a study.
Some policies are exact manuscript implementations, while others are generic
reduced forms or experimental.

## Curves and Outcomes

```julia
y = 0.5
participation = Γ(y, sol.prob.p)
sustainable_participation = Φ(y, sol.prob.p)
income = incomes(sol)
```

- `Γ(y, p)` is the paper's participation curve `P(y)`.
- `Φ(y, p)` is the paper's ordered sustainable-participation curve `I(y)`.
- `incomes(sol)` returns resource, outside-option, policy-transfer, total
  income, Gini, and resource state components.

## Plotting

```julia
using CairoMakie
CairoMakie.activate!()

fig = Figure(size=(1100, 700))
phase_plot!(Axis(fig[1, 1]), with_quota; show_trajectory=true)
incomes_plot!(Axis(fig[2, 1]), with_quota; order=true)
fig
```

Generate current publication figures with the scripts in `manuscript/` and
supplementary figures with `SM_science/supplementary_figures.jl`.

## Repository Map

- `src/`: scientific package implementation.
- `test/`: distribution and paper-alignment regression tests.
- `docs/`: model, policies, distributions, plots, and extension guides.
- `manuscript/`: current main-figure scripts and outputs.
- `SM_science/`: supplementary manuscript, figures, and figure generator.
- `easy/`: compact simulation and visualization wrappers.
- `webapp/`: interactive browser port.
- `examples/`: demonstrations and diagnostics.
- `archive/`: historical implementations and figures.
