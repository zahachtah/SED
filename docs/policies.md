# Policies

## Overview

Policies in SED are defined as types (structs) that subtype `AbstractPolicy`. This allows for efficient dispatch and clear organization of policy-specific parameters. Each policy type implements specific behaviors for:
- **Cost:** How the policy affects the cost of effort (e.g., taxes, fees).
- **Limit:** How the policy constrains effort (e.g., quotas, exclusions).
- **Dynamics:** Additional state variables and their evolution (e.g., market prices).
- **Regulation:** How the policy responds to a regulation intensity parameter `f`.

## Built-in Policies

### Open Access
The default state with no regulation.
```julia
policy = OpenAccess()
```

### Tradable Use Rights (TUR)
Allocates rights to users and allows trading. A market price `ϕ` evolves based on supply and demand.
```julia
policy = TradableUseRights(
    target=:effort,      # :effort or :yield
    market_rate=0.05,    # Speed of price adjustment
    buyer_bias=0.0,      # Bias in trading
    historical_use_rights=false # Allocation based on history
)
```

### Exclusive Use Rights (EUR)
Excludes a subset of users based on a selection criterion (usually efficiency `w̃`).
```julia
policy = ExclusiveUseRights(
    selector=:top,       # :top (exclude high w̃) or :bottom
    reverse=false        # Legacy parameter
)
```

### Protected Area (PA)
Closes a fraction of the resource to extraction.
```julia
policy = ProtectedArea(
    m=0.3                # Fraction of area protected
)
```

### Protected Area Two Pop
A variant of Protected Area that explicitly models two populations (protected and unprotected) with migration.
```julia
policy = ProtectedAreaTwoPop(
    m=0.3                # Fraction of area protected
)
```

### Economic Incentives (EI)
Applies taxes or subsidies to modify user behavior.
```julia
policy = EconomicIncentives(
    target=[:cost],      # Targets: :cost, :limit, etc.
    method=:taxation     # :taxation or :subsidy
)
```

### Development
Models development interventions that affect costs and limits.
```julia
policy = Development(
    μ_value=0.5,
    γ_value=0.5
)
```

## Usage

You can create a scenario with a policy in two ways:

1. **Using Strings (Backward Compatible):**
   The `scenario` function accepts a `policy` string and additional keyword arguments, which are converted to the appropriate struct.
   ```julia
   s = scenario(base(), policy="Tradable Use Rights", market_rate=0.1)
   ```

2. **Using Types (Recommended):**
   You can instantiate the policy struct directly and pass it to `scenario`.
   ```julia
   s = scenario(base(), policy=TradableUseRights(:effort, 0.1, 0.0, false))
   ```

## Governance Objective (Cobb–Douglas)

When scanning regulation, we sometimes want a single scalar objective that trades off several outcomes. We use a Cobb–Douglas product of aggregate metrics.

For each regulation value `r` we compute aggregate metrics:
- `R(r)` = ∑ resource incomes (resource revenues)
- `T(r)` = ∑ total incomes (total revenues)
- `G(r)` = Gini of total incomes (inequality)
- `E(r)` = ecological state (e.g., resource level y)
- `I(r)` = ∑ |uᵒᵃ − u(r)| (impact on behaviour)

And combine them as:
```
Gov(r) = R(r)^kR · T(r)^kT · G(r)^kG · E(r)^kE · I(r)^kI
```

## Warm‑start Scanning

When scanning regulation, “warm‑start” means starting each solve from a good initial condition instead of from scratch.
- `:chain` (default): reuse the steady state from the previous regulation value.
- `:oa_once`: solve Open Access once and use its steady state.
- `:none`: no warm‑start (cold starts).

Example:
```julia
R = regulation_scan(s; m=50, warmstart=:chain)
```
