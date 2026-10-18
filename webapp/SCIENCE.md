# Scientific contract for the browser companion

This is the paper's static companion, not a replacement scientific source of
truth. The manuscript, supplement, and tested Julia implementation retain the
precedence defined in `AGENTS.md`. The experimental development and explicit
two-patch transient workflows are not exposed here.

## Corrections From the Earlier Playground

The previous standalone page predated the current Julia policy implementations.
The following discrepancies were resolved against `src/` and the supplement:

| Mechanism | Current companion behavior |
| --- | --- |
| Participation | Strict `theta < y`, divided by the whole population. Thresholds above one remain outside the plotting window. |
| Sustainable participation | Threshold-ordered potential with fractional marginal-actor interpolation. Insufficient eligible potential gives `NaN`, not a plateau at 100%. |
| Exclusive rights | The Julia binary strong-sanction specialization: selected actors receive a one-unit threshold shift. Selection count uses rounding, as in Julia. The general hinge penalty is explained separately. |
| Rights market | Projected price derivative `0.05 * (sum(z) - Q)`, matching the current Julia implementation. The earlier demand-rate term and incremental rationing rule were removed. |
| Historical rights | Equal `Q / n_OA` among actors with positive open-access use, not shares proportional to historical volumes. |
| Protected area | The protected-patch root uses mobility directly. Equivalent pressure is scaled by `(1-y)/(1-y+h(y))`, matching `protected_pressure_scale` in Julia. |
| Protected-area income | Recover physical use from equivalent pressure; retain the original physical effort endowment. |
| Economic mechanisms | Explicit dimensional transformations, rather than treating the generic Julia `EconomicIncentives` type as an exact causal gear/royalty mechanism. Gear changes both threshold and potential. |
| Economic income | Use the original common numeraire, retain outside returns separately from royalty-adjusted decision thresholds, and do not silently redistribute tax revenue. |
| Initialization | Solve open access once for the realized population; start policy runs from that endpoint. Protected-area state is converted to equivalent pressure at implementation. |
| Convergence | Check projected derivatives and the per-capita resource balance, rather than declaring convergence from a small difference between adaptive steps. Nonconverged runs are identified in the interface. |

Changing an actor's efficiency is a step change in the effective model
parameters. The companion keeps the same initial normalized use state for
economic transformations, as in the package's parameter-change workflow; the
trajectory is not a dimensional transition model of gear acquisition. The
behavioral response rate is held fixed at the selected actor-specific constant
(default 0.05 for every actor).

For convenience the rights-quota slider's upper boundary is the unregulated
case (effort 1, catch 0.5). At that boundary all policy hooks are disabled. For
binding quotas the Julia regulation correspondence is `f = 1 - Q`, including
catch quotas. A nonbinding numerical quota also converges to zero price.

## Sampling and Causal Construction

Direct mode uses lognormal marginal distributions. The threshold mean and
total impact controls set their finite-population values. Deterministic
quantiles are rank-matched to a two-dimensional low-discrepancy Gaussian
copula; random samples use the same latent Gaussian dependence model. Mixed
modes are supported. The displayed pairing parameter is **latent Gaussian
correlation**, not the Pearson correlation after the lognormal transform.

The population builder draws the same actor attributes for each fixed seed,
then predicts `w`, `q`, and `e_bar` with user-editable log-linear pathways.
It derives `theta = w/(p*q*K)` and `u_bar = q*e_bar/r` actor by actor, without
normalizing these derived marginal distributions. Gendered access is an
illustrative social constraint, not an intrinsic biological coefficient.
These distributions are hypothetical; a causal empirical application requires
case-specific evidence and identification assumptions.

The builder holds nondimensional response rates fixed. Its transient rate is
the independently selected `alpha`; the dimensional identity in the supplement
is `alpha = a*p*K*q^2/r^2`. Estimating this response rate from field data is a
separate task from constructing the two static relational distributions.

## Plot Interpretation

- The phase diagram is bounded by `[0,1]` on both axes. The point is the
  simulated endpoint; the curves are computed from that run's parameters and
  market price.
- If zero-threshold users alone can supply pressure of at least one, a
  depleted-resource boundary equilibrium is possible. It is identified
  separately; the positive-stock crossing description does not apply there.
- Blue horizontal overlays show impact mass by **threshold-ordered actor
  rank**, with a darker active part. They are not the marginal density of
  impact values. Their widths are proportional to mass and are only clipped
  by the plotting viewport, not renormalized per scenario.
- Income bars are ordered by the selected variable. Active bars split into
  outside-opportunity income and resource surplus; exited actors are grey.
  Rights payments can be negative and receipts are a separate transfer.
- In total-income order, the grey open-access line is an independently ranked
  income distribution. In threshold, impact, use, and group orders, it follows
  the same actor identities as the policy bars.
- Income values use the common nondimensional scale; no arbitrary factor of
  1000 is applied. The log option is a symmetric log transform and can display
  zero and negative transfers.
- Trajectory spacing resamples the stored numerical path; it does not change
  solver steps. Policy scan weights re-score stored components without
  rerunning the model.

## Verification

`test/model.test.cjs` checks invariants, policy accounting, zero-regulation
limits, sampling, derived dependence, path sampling, and reweighting. When
`JULIA` is set, it runs `test/julia_reference.jl` and compares endpoints,
incomes, prices, and population curves for seven fixed-population cases.
Curve checks avoid exact empirical-threshold jumps, where small numerical
price differences can select either boundary of a valid participation segment.

`test/ui.test.cjs` checks real browser interactions and desktop/mobile layouts
when a local Playwright browser is available. A successful engine test is not
a visual layout verification.
