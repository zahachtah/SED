# Model and Paper Crosswalk

This document records how the current Julia implementation maps to the
manuscript and supplementary material. The main paper is the scientific ground
truth. Internal field names are retained for compatibility.

## State and Parameters

| Meaning | Paper notation | Julia implementation |
| --- | --- | --- |
| Actor use | `u_i` | `x[i]`, `i=1:N` |
| Resource density | `y` | `x[N+1]` |
| Dimensional stock | `x` | not stored directly |
| Dimensional response coefficient | `a_i` | not stored directly |
| Exit threshold | `\theta_i` | scenario field `w̃` |
| Impact potential | `\bar u_i` | scenario field `ū` |
| Nondimensional response rate | `\alpha_i` | scenario field `α` |

`α` may be scalar or actor-specific. `w̃` and `ū` may be vectors or realized
`SEDist` objects.

## Actor Dynamics

Paper:

```math
\frac{du_i}{d\tau}
=\alpha_i\left(y-\theta_i\right),
\qquad 0\le u_i\le\bar u_i.
```

Code: `dxdt` in `src/model.jl` evaluates

```julia
dx[1:N] = p.α .* (x[N+1] .- p.cost(x, p, t))
```

and `stage_limiter!` clamps actor states to `[0, p.limit(...)]`. Policies act
through `cost` and `limit`, so the baseline corresponds to
`cost=\theta_i` and `limit=\bar u_i`.

Status: direct match.

## Resource Dynamics

Paper:

```math
\frac{dy}{d\tau}
=y\left(1-y-\sum_i u_i\right).
```

Code:

```julia
dx[N+1] = x[N+1] * ((1 - x[N+1]) - sum(x[1:N]))
```

Status: direct match.

## Participation Curve

Paper:

```math
P_-(y)=\frac{1}{N}\sum_i\mathbf{1}(\theta_i<y).
```

Code: `Γ(y, p)` computes the strict lower participation boundary. At an exact
threshold, the manuscript's participation curve includes the vertical interval
to the weak-inequality boundary; simulated marginal use selects a point on that
segment.

Status: direct match, including the strict inequality.

## Sustainable-Participation Curve

Actors are ordered by policy-adjusted exit threshold. Let
`\bar u_{(j)}` be impact potentials in that order and
`C_k=\sum_{j=1}^k\bar u_{(j)}`. At resource density `y`, replacement requires
pressure `1-y`. If `C_k < 1-y <= C_{k+1}`, then

```math
I(y)=\frac{1}{N}\left[
k+\frac{1-y-C_k}{\bar u_{(k+1)}}
\right].
```

Code: `Φ(y, p)` applies this ordering and marginal-actor interpolation.
Actors with policy-adjusted thresholds above one are ineligible on the
non-dimensional resource domain and are excluded from the maximum attainable
share.

Status: direct match to
`SupplementaryMaterial/sections/03_participation_balance.tex`.

## Attractor

The geometric attractor satisfies:

```math
P(y^*)=I(y^*).
```

The ODE endpoint and curve crossing should agree up to numerical tolerance.
Finite response rates change the trajectory, not the equilibrium geometry,
provided the same policy-adjusted thresholds and limits apply.

For the baseline projected dynamics, a Lyapunov function proves convergence
from every positive-resource initial condition to the unique equilibrium
resource density. If at most one actor is marginal, the full equilibrium is a
globally asymptotically stable point; tied marginal actors produce a globally
attracting set of allocations with the same resource density and total use.
See `SupplementaryMaterial/sections/03_participation_balance.tex`. The proof
also covers fixed policy transformations of thresholds and limits, but not
policies with additional dynamic states or resource-dependent limits.

## Income Accounting

The implementation returns:

- resource income: `u_i y`, optionally multiplied by a policy access factor;
- outside-option income: `(\bar u_i-u_i)\theta_i`;
- policy transfer: policy-specific extra income, including rights-market rent;
- total income: the sum of these components.

With `dimensional=true`, components are multiplied by scenario field `rpk`.
The paper's exact dimensional interpretation therefore depends on how the
scenario constructs `w̃`, `ū`, and `rpk`.

For `ProtectedArea`, the simulated actor state is ecological-equivalent use
scaled by `kappa(y)=(1-y)/(1-y+h(y))`. Income accounting first recovers
physical use by dividing by `kappa(y)` and uses the original physical
endowment; the ecological transform is not treated as lost gear or time.

## Policy Crosswalk

| Policy | Code behavior | Scientific status |
| --- | --- | --- |
| Open access | Baseline thresholds and limits | Direct |
| Exclusive rights | Selected actors receive a one-unit threshold shift | Binary strong-sanction specialization |
| Tradable rights | Dynamic price shift, quota convergence, rent transfer | Numerical implementation of paper mechanism |
| Protected area | Access scaling plus mobility-derived spillover | Tested one-resource reduced form |
| Economic incentives | Generic additive/multiplicative transforms | Reduced-form geometry |
| Protected area, two populations | Explicit two-patch resource equations | Equation-aligned, experimental workflow |
| Development | Time-varying threshold/limit shifts | Experimental |

See `docs/policies.md` for interpretation details.

## Known Scientific Risks

1. `ProtectedAreaTwoPop` matches the current two-patch resource equations, but
   its full simulation and income workflow has less coverage than the reduced
   protected-area model. Treat study use as experimental.
2. `EconomicIncentives` is intentionally generic. A label such as "royalty" or
   "gear subsidy" requires a derivation-specific transform.
3. Tradable-rights equilibrium is numerical. A run must demonstrate quota and
   price convergence rather than assume it.
4. Internal `w̃` and `ū` names are legacy notation. Renaming them requires a
   coordinated migration across source, figures, web app, and archived studies.
5. `gini` assumes a positive aggregate total income; scenarios with zero or
   negative aggregate income require a deliberate inequality convention.

## Regression Coverage

`test/test_model_alignment.jl` checks:

- the strict participation criterion;
- ordered cumulative-impact interpolation;
- exclusion of thresholds outside the feasible resource domain;
- ODE state bounds;
- exclusive-rights selection and threshold shifts;
- tradable-rights quota totals, price shifts, and transfer balance;
- protected-area threshold and impact directions;
- the explicit protected-area two-patch resource equations.

Run:

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```
