# Policies

Policies are Julia types that subtype `AbstractPolicy`. A policy can transform:

- `cost`: the exit-threshold vector used in actor dynamics.
- `limit`: the actor impact-potential vector.
- `dynamics`: additional state equations, such as a rights price.
- `regulate`: scenario parameters at a policy intensity `f`.
- income hooks: resource-income factors or transfers.

For every policy, regulation level `f=0` is the mathematical open-access
boundary: policy transformations and any auxiliary coupling to the baseline
state equations are inactive.

Construct a policy explicitly and pass it to `scenario`:

```julia
regulated = scenario(
    baseline;
    policy=TradableUseRights(:effort, 0.05, 0.0, false),
)
sol = sim(regulated; regulation=0.4, start_from_OA=true)
```

String policy names remain supported by `scenario` for older scripts, but typed
constructors are clearer and safer.

## Open Access

```julia
OpenAccess()
```

Open access leaves exit thresholds and impact potentials unchanged.

## Exclusive Use Rights

```julia
ExclusiveUseRights(:top, false)
```

The selector is `:top`, `:bottom`, or `:random`. The regulated fraction is
selected using the internal exit-threshold field `w̃`, matching the manuscript
comparison.

This is the paper's binary strong-sanction specialization. The internal `R`
vector is an exclusion mask:

- `R_i=0`: actor is permitted.
- `R_i=1`: actor is excluded, shifting the effective exit threshold above the
  feasible resource domain.

This differs from tradable policy notation, where `R_i` is an allocated
quantity of rights. Do not interpret the exclusive-policy mask as a divisible
entitlement.

## Tradable Use Rights

```julia
TradableUseRights(
    :effort,  # :effort or :yield
    0.05,     # market-price adjustment rate
    0.0,      # buyer bias
    false,    # historical initial allocation
)
```

For regulation level `f`, aggregate rights equal `Q=1-f`. With `:effort`,
`Q`, `R_i`, supply, and demand are measured in realized effort `u_i`; with
`:yield`, they are measured in catch `y*u_i`. Rights are initially equal among
all actors or, when historical allocation is enabled, equal among actors with
positive open-access use. Historical use determines eligibility, not the size
of each actor's endowment. The numerical market:

- applies price wedge `\phi` for effort rights or `y*\phi` for catch rights;
- adjusts `\phi` from current rights deficits minus unused rights, equivalently
  `sum(z_i)-Q`;
- permits temporary excess use to feed back into the numerical price;
- records `(R_i-u_i)\phi` or `(R_i-y*u_i)\phi` as a transfer.

Transfers sum to zero when aggregate use equals the quota. Check quota balance
and price convergence before interpreting a run.

At `f=0`, the price and transfer hooks are inactive, so the policy
equations reduce exactly to open access.

For the optional `:yield` target, rights are measured in catch units `y*u_i`.
The price wedge is therefore `y*\phi`, and marginal return is
`y*(1-\phi)-\theta_i`. Figure 4 uses `:effort`.

## Protected Area

```julia
ProtectedArea(0.3)
```

The constructor argument is mobility/spillover `m`, not protected fraction.
The simulation keyword `regulation=f_p` is the protected fraction.

The tested one-resource reduced form:

- rescales thresholds by `1/(1-f_p)` because only the open fraction can be
  used;
- maps physical impact to ecological-equivalent impact with
  `kappa(y)=(1-y)/(1-y+h(y))`, where the explicit two-patch equilibrium is
  `sum(u)=1-y+h(y)`;
- scales resource income by the accessible fraction.

Its quasi-steady protected-patch density is derived from
`y_p*(1-y_p)-m*(y_p-y)=0`; the protected fraction appears in the reciprocal
area scaling of spillover into the exploited patch.

The transformed limit is used only for the reduced ecological dynamics and
phase geometry. Income accounting converts realized equivalent use back to
physical use and retains the original physical impact endowment. The explicit
`ProtectedAreaTwoPop` model keeps physical actor limits unchanged because its
resource equation already contains the spillover flux.

## Economic Incentives

```julia
EconomicIncentives([:cost], :additive)
EconomicIncentives([:limit], :multiplicative)
```

Targets can include `:cost`/`:incentives` or `:limit`/`:impact`. Methods are
generic additive or multiplicative transformations, with `:taxation` using the
opposite multiplicative direction.

This policy is a reduced-form geometry tool. It does not, by itself, guarantee
the exact dimensional identities for a proportional royalty, gear subsidy, or
outside-income intervention. Derive a study-specific policy type when the
causal interpretation matters.

## Experimental Policies

`ProtectedAreaTwoPop` and `Development` are retained for ongoing development.
Their equations and initialization have not yet received the same
paper-alignment regression coverage as the policies above. Do not use them for
inferential studies without an explicit derivation and new tests.

## Policy Scans

```julia
scan = regulation_scan(
    regulated;
    m=50,
    warmstart=:chain,
    kR=0.5,
    kT=1.0,
    kG=-0.2,
)
```

Warm starts:

- `:chain`: initialize each point from the preceding solution.
- `:oa_once`: initialize every policy point from one open-access solution.
- any other value: cold starts.

The governance score is a Cobb-Douglas product of resource income, total
income, Gini, ecology, and behavioral policy impact. Exponents are analysis
choices, not model parameters, and should be reported.

## Adding a Policy

See [`custom_policies.md`](custom_policies.md). At minimum:

1. subtype `AbstractPolicy`;
2. implement only the dispatch methods the policy changes;
3. add an equation-level note to the model-paper crosswalk;
4. test thresholds, limits, state bounds, incomes, and any accounting identity;
5. compare the simulated endpoint with `Γ` and `Φ`.
