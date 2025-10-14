# Policies

Idea first

Policies answer a simple question: how do rules change incentives, impacts, and possibly add extra dynamics? In SED a policy is just a small bundle of functions that plug into the same ODE model. No type hierarchies—only functions and a few optional hooks—so modeling stays intuitive and composable.

Details

This page describes how to define and use policies in SED. Policies are simple functions that specify how incentives (γ), impacts (μ), optional dynamics (ϕ), and regulation behavior interact with the simulation. The design is function‑first so you can bring your own rules without boilerplate.

Core ideas

- Required functions (duck-typed):
  - `γ(x, p, t)`: incentive rate per agent
  - `μ(x, p, t)`: impact (upper bound on use) per agent
  - `ϕ(dx, x, p, t)`: optional extra ODE dynamics (e.g., market price)
  - `regulate(p, f) -> p′`: apply regulation level `f ∈ [0,1]` to scenario `p`
- Optional hooks:
  - `income_extra_fun(x, p, t) -> Vector`: adds an income component per agent (e.g., trades, transfers)
  - `resource_factor_fun(x, p, t) -> Number|Vector`: scales resource income (e.g., `(1 - f)` for protected area)
  - `extra_state::Int` and `init_extra_state(p)::Vector`: policy ODE state extensions
  - `label::String` and `policy_meta::NamedTuple`: display/meta information
- Helper: `with_policy(s; ...)` merges any subset of these into a new scenario.

Quick start

```julia
include("SED.jl"); using .SED

# Baseline
N = 100
s0 = scenario(base(N=N))

# Add a simple incentive bonus policy
γ_bonus(x, p, t) = p.w̃ .+ 0.05
s = with_policy(s0; γ=γ_bonus, label="γ + 0.05")
sol = sim(s; regulation=0.2)
inc = incomes(sol)
println("y*=", round(sol.u[end][end], digits=3), "  ToR=", round(sum(inc.total), digits=3))
```

When to use with_policy vs scenario(...; policy="…")

- Use `with_policy(s; ...)` to layer a policy onto an existing scenario `s` (and when using kits). It returns a new scenario without modifying `s`.
- Use `scenario(...; policy="…")` when you define a policy “in one shot” and need to set the policy string so `sim` adds any extra ODE state (e.g., TUR price).

Tradable Use Rights (function-based)

The built-in functions for TUR attach an `income_extra_fun` during `regulate(...)`, so trade revenues appear in `incomes` without name checks.

```julia
s_tur = scenario(base(N=N);
  γ=γ_tradable_use_rights,
  ϕ=ϕ_tradable_use_rights,
  regulate=regulate_tradable_use_rights,
  policy_target=:effort, market_rate=0.05)
sol = sim(s_tur; regulation=0.3)
inc = incomes(sol)   # inc.extra (alias inc.trade) holds the trade income
```

Policy kits (one-liners)

Kits are tiny helpers that return a bundle of functions and hooks you can pass to `with_policy`:

```julia
# Exclusive Use Rights: top by w̃
sel = (w̃, n) -> sortperm(w̃, rev=true)[1:n]
eur = with_policy(s0; exclusive_use_rights_kit(; selector=sel)...)

# Tradable Use Rights
tur = with_policy(s0; tradable_use_rights_kit(; target=:effort, market_rate=0.05)...)

# Protected Area
pa = with_policy(s0; protected_area_kit(; m=0.3)...)
```

The kits produce the same outcomes as the “manual” function-based policies above but with fewer moving parts. Edit the returned fields or pass different keyword args to explore variants.

TUR supply choice (why aggregate clamp)

Idea: rights are pooled; price should respond to net slack across all agents.

- Aggregate clamp (default): `clamp(sum(R - usage), 0, Inf)`
  - Overuse cancels underuse; supply is zero until there is net slack.
  - Fewer kinks → smoother price; intuitive scarcity pricing; better stability.
- Element‑wise clamp: `sum(clamp.(R - usage, 0, Inf))`
  - Counts local underuse even if others overuse more → misprices scarcity.
  - Many kinks; choppy price; can destabilize solves.

Heuristics and tips

- Effort target: MSY ≈ 0.5 → expect optimal regulation near f ≈ 0.5.
- Yield target: MSY ≈ 0.25 → expect optimal regulation near f ≈ 0.75.
- If price collapses quickly, try `high_impact` baselines, moderate `market_rate`, and warm‑starts.
- See `examples/tur_supply_compare.jl` to visualize price traces and phase plots for both supply definitions.

Protected Area (function-based)

The built-in `regulate_protected_area` also attaches `resource_factor_fun` so resource income scales by `(1 - f)`.

```julia
s_pa = scenario(base(N=N);
  γ=γ_protected_area,
  μ=μ_protected_area,
  regulate=regulate_protected_area,
  m=0.3)
sol = sim(s_pa; regulation=0.3)
inc = incomes(sol)  # resource income already scaled
```

Scanning and goals

```julia
R = regulation_scan(s_tur; m=50)
opt = R.r[R.oGov]  # pick by Gov, or use ToR/EH/etc.
sol_opt = sim(s_tur; regulation=opt)
```

Figures

 - See `examples/policy_tests.jl` for a runnable script comparing policies and printing summary metrics.
 - See `examples/policy_scans.jl` for `policy_phase_plots(T)` which optimizes regulation per policy and returns a multi-panel figure.
 - Warm-start scan figure: `examples/warmstart_scan_figure.jl` saves `examples/figures/warmstart_scan.png`.
 - Manuscript figures: run `manuscript/figures.jl` to regenerate publication figures.
 - One-shot build: run `scripts/build_docs_figures.jl` to regenerate README and docs figures.

Notes

- This API avoids policy type hierarchies to keep custom extension simple: provide functions and optional hooks, compose freely.
- Existing examples using `scenario(...; policy="…")` continue to work. Built-ins (e.g., TUR/PA) now add hooks internally where needed.

Warm‑start scanning

- What it is: When scanning regulation, “warm‑start” means starting each solve from a good initial condition instead of from scratch. This greatly reduces time‑to‑steady‑state.
- Options in `regulation_scan(...; warmstart=...)`:
  - `:chain` (default): reuse the steady state from the previous regulation value as the initial condition for the next. Best for monotone sweeps over `r`.
  - `:oa_once`: solve Open Access once (`regulation=0.0`) to get `(u*, y*)`, then use that as the initial condition for all regulation values.
  - `:none`: no warm‑start; each value starts from zeros (legacy behavior).
- Helper: `sim_init(p; from=:zeros | :oa)` returns initial conditions matching the scenario shape; `from=:oa` performs one OA solve and returns its steady state.
- Usage examples:
```julia
R = regulation_scan(s; m=50, warmstart=:chain)    # fastest over small steps
R = regulation_scan(s; m=50, warmstart=:oa_once)  # single OA warm start, then scan
R = regulation_scan(s; m=50, warmstart=:none)     # cold starts only
```
When to use which:
- Use `:chain` for dense scans (small step size) where the steady state changes gradually.
- Use `:oa_once` when you want a single, comparable baseline for all points.
- Use `:none` for debugging or when you specifically want cold starts.
