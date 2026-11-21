# Building an Actor Population

`dist` describes a quantity; `sample!` realizes its actor-level values. A
quantity can be a distribution, observed data, a constant, or a function of
other actor quantities. Dependencies are resolved in order, so the same
person's income, efficiency, and effort remain linked.

## Start From Dimensional Quantities

This small illustrative population follows the construction used in Figure 2:

```julia
using SED, Random
Random.seed!(42)

population = scenario(base(N=115);
    price=1.0, Kdim=1.0, rdim=1.0,
    aio=dist(distribution=LogNormal, median=0.34, sigma=0.52),
    q=dist(distribution=LogNormal, median=0.98, sigma=0.06,
        dependency_fun="independent * (aio / 0.34)^0.65"),
    effort_cap=dist(distribution=LogNormal, median=0.0106, sigma=0.18),
    w̃=dist(dependency_fun="aio / (price * q * Kdim)"),
    ū=dist(dependency_fun="q * effort_cap / rdim"),
    α=0.05)

sample!(population; random=true)
result = sim(population)
```

Here `independent` is the quantity's own draw, so efficiency is conditionally
lognormal given outside income. The exponent controls one pathway linking the
two. Exit thresholds and impact potentials are then **derived for each actor**,
not sampled independently afterward.

The numerical constants are illustrative and carry no empirical calibration.
For a causal application, use context-specific data to identify which
attributes affect outside opportunities, catchability, and available time.

## Observed Data and Julia Functions

Use `dist(data=values)` to retain observed actor records. Use `@dependent`
when a Julia expression is clearer than a string:

```julia
thresholds = dist(dependency=@dependent (aio, q) -> aio ./ q)
```

This example assumes `price=Kdim=1`; include those terms explicitly when they
differ. The macro infers the named dependencies. A population with dependent
variables preserves their actor identities when policies are compared.

## Ordered Quantiles or Random Draws?

- `sample!(population; random=false)` uses deterministic ordered quantiles.
  This gives smooth comparative geometry without finite-sample noise.
- `sample!(population; random=true)` uses random draws. Set and report the RNG
  seed before sampling.
- Sample **once** before making policy scenarios. Resampling a policy scenario
  would confound population differences with policy effects.

For `LogNormal`, `median` and `sigma` describe the median and log-scale spread.
When `min` and `max` are used instead, they specify quantile anchors, not an
automatic hard truncation. The default anchors are the 0.01 and 0.99 quantiles;
deterministic `:within` sampling stays between them, while random `:none`
sampling can reach the tails. `determ_bounds`, `random_bounds`, and
`bounds_quantiles` make these choices explicit.

`normalize=true` rescales a realized quantity to sum to one. Use it only when
that normalization is part of the study design. In particular, **do not
normalize empirical exit thresholds to the resource plotting window**:
thresholds above one are valid, and participation at `y=1` can remain below
100%.

For a full runnable example, see [Figure 2](../manuscript/figure2.jl).
The supplementary discussion of empirical interpretation is pending approval
for release. Distribution construction and dependency behavior are covered by
the public model tests.
