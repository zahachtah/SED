# SED Repository Guide for AI-Assisted Studies

This file is the operational and scientific guide for an AI agent working in
this repository. Read it before modifying the model, generating results, or
interpreting a figure.

## Scientific Purpose

SED models a renewable resource used by heterogeneous actors. Actor-level exit
thresholds and impact potentials generate two population curves whose crossing
predicts the social-ecological attractor:

```math
\frac{du_i}{d\tau}=\alpha_i\left(y-\theta_i\right),
\qquad 0\le u_i\le\bar u_i,
```

```math
\frac{dy}{d\tau}=y\left(1-y-\sum_i u_i\right).
```

At resource density `y`, the participation curve is

```math
P_-(y)=\frac{1}{N}\sum_i \mathbf{1}(\theta_i<y).
```

The required-participation curve orders actors by
`\theta_i` and asks what fraction of the full population is required for
cumulative impact potential to equal replacement pressure `1-y`. The
implementation interpolates within the marginal actor.

## Source of Truth

When sources disagree, use this order:

1. `Science_MS_compact.pdf`, rendered from `manuscript/AN_compact-6.docx`.
2. `SupplementaryMaterial/main.tex` and the files it includes.
3. Tested model behavior in `src/`.
4. Figure scripts in `manuscript/` and `SupplementaryMaterial/scripts/`.
5. Historical prose in `manuscript/MS.txt` and any local ignored archives or
   exploratory files.

Do not silently resolve a scientific disagreement. Record the discrepancy,
identify which source is being followed, and add a regression test before
changing model behavior.

## Notation Crosswalk

The paper notation and some internal Julia names differ:

| Scientific meaning | Paper / SM | Julia |
| --- | --- | --- |
| Resource density | `y` | `x[N+1]` |
| Realized use or effort | `u_i` | `x[1:N]` |
| Dimensional resource stock | `x` | not stored directly |
| Dimensional response coefficient | `a_i` | not stored directly |
| Exit threshold | `\theta_i` | `w̃` |
| Impact potential | `\bar u_i` | `ū` |
| Nondimensional response rate | `\alpha_i` | `α` |
| Participation curve | `P(y)` | `Γ(y, p)` |
| Sustainable-participation curve | `I(y)` | `Φ(y, p)` |
| Use-right allocation | `R_i` | `R` for TUR; see EUR warning below |
| Tradable-rights price | `\phi` | final state `x[N+2]` |

Keep the legacy Julia field names unless doing a coordinated migration. Use
paper notation in prose, plots, and study reports.

## Model-to-Code Map

- `src/core.jl`: distribution sources, dependency graph, ordered/random
  sampling, `Dist`/`SEDist`.
- `src/model.jl`: ODE, state bounds, initialization, and `sim`.
- `src/metrics.jl`: `P(y)`, `I(y)`, incomes, Gini, and policy scans.
- `src/scenarios.jl`: open-access primitives and scenario construction.
- `src/policies.jl`: policy types and policy-specific dispatch.
- `src/plots.jl`: phase, income, distribution, and dependency plots.
- `webapp/`: interactive JavaScript port. It is not the scientific source of
  truth; parity changes require comparison with `src/` and tests.

See `docs/model-paper-crosswalk.md` for equation-level details and known
limitations.

## Policy Fidelity

Use these classifications in study design and reporting:

- `OpenAccess`: direct implementation of the baseline model.
- `TradableUseRights`: dynamic numerical rights market with effort or yield
  quotas, equal rights for all actors or equal historical rights among actors
  with positive open-access use, price-adjusted exit thresholds, rationing,
  and rent transfers. Market-clearing behavior is algorithmic and should be
  checked for convergence in each study.
- `ExclusiveUseRights`: binary strong-sanction specialization. Internally,
  `R_i=1` means excluded and shifts the threshold by one full resource unit;
  this internal mask is not a divisible use-right entitlement.
- `ProtectedArea`: tested one-resource reduced form. `regulation=f_p` is the
  protected fraction and `ProtectedArea(m)` stores mobility/spillover.
- `EconomicIncentives`: generic reduced-form additive or multiplicative
  transforms. It is not automatically an exact dimensional royalty or gear
  subsidy. For causal policy studies, derive and test the desired transform.
- `ProtectedAreaTwoPop` and `Development`: experimental. Do not use them for
  inferential results without reconciling their equations with the paper and
  adding focused tests.

## Reproducible Study Workflow

1. Record the git commit, Julia version, `Project.toml`, and `Manifest.toml`.
2. Define dimensional empirical distributions or constants where possible.
3. Derive `w̃` and `ū` through explicit dependencies; do not fit them
   independently if the study claims a dimensional causal interpretation.
4. Choose sampling deliberately:
   - `random=false`: deterministic ordered quantiles for clean comparative
     geometry.
   - `random=true`: random finite-population draws for stochastic studies.
5. Fix and report the RNG seed for random studies.
6. Call `sample!` once and preserve the realized actor population when
   comparing policies.
7. Simulate open access first.
8. Start policy simulations from the open-access attractor unless the research
   question explicitly concerns initial colonization or recovery.
9. Check solver convergence, state bounds, quota balance, and market-price
   convergence.
10. Compare simulated endpoints with the crossing of `Γ` and `Φ`.
11. Report participation, resource density, total pressure, income components,
    inequality, and the full policy parameterization.
12. Save code and tabular results, not only rendered figures.

Never compare an ordered population with a newly sampled random population and
attribute the difference to policy.

## Setup and Verification

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. -e 'using Pkg; Pkg.test()'
```

For headless figures:

```julia
using CairoMakie
CairoMakie.activate!()
using SED
```

Representative figure scripts:

```bash
julia --project=. manuscript/figure_intro_dimensional_pipeline.jl
julia --project=. manuscript/figure3_relational_variables.jl
julia --project=. manuscript/figure4_policy_transformations.jl
julia --project=. SupplementaryMaterial/scripts/generate_figures.jl
```

Inspect generated PDF and PNG files visually. A successful script is not a
layout verification.

## Coding and Repository Rules

- Use four-space indentation and small functions.
- Keep public exports in `src/SED.jl`.
- Add a focused test for every scientific behavior change.
- Prefer structured Julia APIs to string manipulation.
- Preserve Unicode identifiers already used by the model.
- Do not edit generated LaTeX auxiliaries or derived PNG/PDF files by hand.
- Do not move or delete manuscript outputs unless the user explicitly requests
  an archival cleanup.
- Treat local ignored archives and debug scripts as historical unless promoted
  and tested.
- Keep publication figures in `manuscript/figures/` and supplementary figures
  in `SupplementaryMaterial/figures/`.
- Keep temporary diagnostics in `tmp/` or `tmp_outputs/`; these are ignored.

## Before Reporting Results

Confirm all of the following:

- The paper notation is used in labels and prose.
- `P_-(y)` uses the strict criterion `\theta_i<y`; at an exact threshold,
  participation spans the vertical interval to the weak-inequality boundary.
- `I(y)` uses actors ordered by `\theta_i` and includes the marginal-actor
  interpolation.
- Actors with `\theta_i>1` are not counted as eligible on `y\in[0,1]`.
- Policy and open-access runs use the same realized population.
- Policy runs begin from the intended initial state.
- TUR quota totals, price, and transfer accounting are numerically sensible.
- Any reduced-form or experimental mechanism is identified as such.
- `Pkg.test()` passes.
