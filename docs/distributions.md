# Distributions

Explains independent vs dependent distributions, function vs string dependency functions, and the `independent` shorthand in strings.

Topics

- Independent: `dist(min/max/mean/median/sigma; distribution, random, normalize)`
- Dependent (function): `dist(dependent=(...), dependency_fun=(indep, dep)-> ...)`
- Dependent (string): `dist(dependency_fun="...")` with `independent` bound to the base vector
- Allowed functions inside strings: `min`, `max`, `clamp`, `abs`, `sqrt`, `exp`, `log`.
  These auto‑broadcast when any argument is a vector (e.g., `max(0.0, independent)`).
- Sampling: `sample!(dist, N; random)` vs `sample!(context; N, random)`
- Weighted dependents and broadcasting rules

Sampling Policy Options

These options live on each `Dist` and control how min/max for LogNormal is interpreted and how sampling treats bounds:

- `bounds_quantiles::(Float64,Float64)` (default `(0.01, 0.99)`):
  Interprets `min,max` as the `(qlo,qhi)` quantiles for LogNormal, and fits `(μ,σ)` accordingly.

- `determ_bounds::Symbol` (default `:within`): controls deterministic (random=false) quantile grid
  - `:within`: sample quantiles only inside `[qlo,qhi]` so values stay in `[min,max]` independent of `N`.
  - `:full`: classic grid `[1/N, …, 1−1/N]` (can go outside `[min,max]` for large `N`).
  - `:clip`: sample full grid, then clamp quantiles into `[qlo,qhi]`.

- `random_bounds::Symbol` (default `:none`): controls random (random=true) draws
  - `:none`: draw from the full LogNormal; tails outside `[min,max]` occur with probability `1−(qhi−qlo)`.
  - `:truncate`: approximate truncation by rejecting/replacing samples outside `[min,max]`.

- `enforce_after_deps::Symbol` (default `:none`): post‑dependency enforcement on final values
  - `:none`: do nothing.
  - `:clamp`/`:truncate`: clamp final values into `[min,max]`.

Applicability

- These options affect the LogNormal(min,max) path. For other distributions (Uniform, Bernoulli, Dirac), they do not change sampling and are ignored with a notice.
