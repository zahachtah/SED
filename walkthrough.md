# Refactoring Walkthrough: Dist Struct and Policy System

This document summarizes the major refactoring work completed to modularize the `Dist` struct and make the Policy system composable.

## 1. `Dist` to `SEDist` Refactoring

The monolithic `Dist` struct has been replaced by a modular `SEDist` struct that composes a **Source** and a **Dependency**.

### New Structure
- **`SEDist{S, D}`**: Main type.
  - `source::S`: Where the base values come from.
  - `dependency::D`: How values are modified by other variables.

### Sources (`AbstractSource`)
- **`RandomSource`**: Parametric distributions (e.g., `LogNormal`, `Uniform`).
- **`DataSource`**: Fixed data vectors.
- **`ZeroSource`**: For pure dependency placeholders.

### Dependencies (`AbstractDependency`)
- **`NoDependency`**: Identity (independent).
- **`FunctionalDependency`**: Defined by a function `(independent, inputs...) -> output`.

### Usage
The `dist()` factory function remains the primary API but now returns `SEDist`.

```julia
# Independent
w = dist(mean=0.5, sigma=0.1, distribution=LogNormal)

# Dependent (using @dependent macro)
w_dep = dist(dependency = @dependent (q) -> 0.5 .* q .+ independent,
             distribution=Normal, mean=0, sigma=0.1)
```

## 2. The `@dependent` Macro

A new macro `@dependent` simplifies defining dependencies using native Julia syntax.

### Features
- **Automatic Injection**: Automatically injects `independent` as the first argument.
- **Aliasing**: Supports `sed` as an alias for `independent`.
- **Type Safety**: Returns a `FunctionalDependency` object instead of a string.

### Example
```julia
# Old (String-based)
dist(dependency_fun = "0.5 .* q .+ independent")

# New (Macro-based)
dist(dependency = @dependent (q) -> 0.5 .* q .+ independent)
```

## 3. Composable Policy System

The Policy system has been overhauled to support multiple active policies simultaneously.

### Key Changes
- **`policies` List**: The `Scenario` NamedTuple now contains a `policies::Vector{Any}` list.
- **`with_policy`**: Appends new policies to this list instead of overwriting functions.
- **Master Functions**: `master_γ`, `master_μ`, and `master_ϕ` iterate over all active policies and chain their effects.
  - `γ` and `μ` are chained: `val = pol.γ(val, ...)`
  - `ϕ` is additive/side-effect: `pol.ϕ(dx, ...)`
- **Closures in Kits**: Policy kits (e.g., `development_kit`) now use closures to capture parameters, preventing namespace pollution and conflicts.

### Example: Composition
```julia
# Apply Policy 1
s1 = with_policy(base_scenario; economic_incentives_kit(...)...)

# Apply Policy 2 (on top of Policy 1)
s2 = with_policy(s1; development_kit(...)...)

# Run simulation (both policies active)
sol = sim(s2)
```

## 4. Verification Results

### `examples/simple_verification.jl`
- **Status**: Passed
- **Description**: Verified `SEDist` refactoring, `@dependent` macro, and basic simulation with dependencies.
- **Key Checks**:
    - Independent distribution sampling.
    - Dependent distribution calculation (linear dependency).
    - Simulation runs without error.

### `examples/policy_composition_verification.jl`
- **Status**: Passed
- **Description**: Verified composition of multiple policies (Economic Incentives + Development).
- **Key Checks**:
    - Policies are correctly appended to `policies` list.
    - `master_γ` correctly chains policy effects.
    - Simulation reflects combined effects (e.g., `γ` increasing over time due to development).

### `examples/verify_all_policies.jl`
- **Status**: Passed
- **Description**: Comprehensive test of all default policies in `default_regulation_scan_policies`.
- **Key Checks**:
    - "Exclusive Use Rights" (High/Low Opp)
    - "Tradable Use Rights" (Effort/Yield, Regressive/Progressive)
    - "Protected Area" (with/without tourism)
    - All simulations run to completion.
    - `phase_plot` generates plots without error (verified via script completion).

### Fixes Implemented during Verification
- **`UndefVarError: γ`**: Fixed by aliasing `γ`, `μ`, `ϕ` to `master_γ`, `master_μ`, `master_ϕ` in `src/scenarios.jl` and explicitly using master functions in `src/plots.jl`.
- **`BoundsError` in `ϕ_tradable_use_rights`**: Fixed by ensuring `phase_plot!` clears the `policies` list when creating the "Open Access" baseline scenario, preventing policy hooks from running on an incompatible state vector.
- **`MethodError` in `dist`**: Fixed by handling `kw` arguments correctly in `build_distribution`.
- **`MethodError` in `sample!`**: Fixed by adding `force` keyword argument and handling `NamedTuple` dispatch.

## 5. Conclusion
The refactoring of `Dist` to `SEDist` and the Policy system to a composable architecture is complete and verified. The system now supports:
1.  **Modular Distributions**: Sources and dependencies are distinct, with a flexible `@dependent` macro.
2.  **Composable Policies**: Policies can be stacked, and their effects are applied sequentially via master functions.
3.  **Robust Simulation**: The simulation loop correctly handles dynamic state sizes (e.g., for Tradable Use Rights) and policy hooks.

**Problem**: The `regulation_scan_plot` function was generating widespread `dt < epsilon` warnings and "Simulation failed" errors, particularly for `Protected Area` policies.

**Analysis**:
*   Identified a singularity in the spillover equation (`rₛ`) for Protected Areas.
*   The term `(yₚ - y) / y` explodes as the biomass in the fishing area (`y`) approaches zero.
*   This caused the carrying capacity `μ` to behave erratically, leading to solver instability (`Unstable` or `MaxIters`).

**Fix**:
*   Modified `src/policies.jl` to regularize the division by `y`.
*   Replaced `... / y` with `... / max(y, 1e-6)` in both `rₛ` and `μ_protected_area_two_pop`.

**Result**:
*   `Protected Area` simulations are now stable, and cold starts succeed reliably.
*   Occasional `MaxIters` warnings during warmstart chains are handled gracefully by the existing retry logic (falling back to cold start), ensuring correct results without "botched" flat curves.

## Debugging TUR Revenue Curves

**Problem**: "Tradable Use Rights" policies showed a flat resource revenue curve. The user pointed out that legacy code worked perfectly and used a specific implementation (`sum(clamp)` for supply).

**Analysis**:
*   The legacy implementation (`sum(clamp.(R - usage))`) relies on `R` being strictly less than `usage` for all agents to generate a positive price.
*   However, the previous quota calculation (`R = (1-f)/N`) often resulted in `R > usage` for inefficient agents (creating infinite supply) or `Total R > Total Usage` (making regulation non-binding).
*   Additionally, the Open Access (OA) baseline calculation inside `regulate` was unstable, leading to incorrect quota allocations.

**Fix**:
1.  **Restored Legacy Logic**: Reverted `ϕ` to use `sum(clamp.(...))` as requested.
2.  **Relative Quota**: Implemented `R = Baseline * (1 - f)` for both Effort and Yield. This ensures that regulation is always binding (quota < usage) and `f` represents a percentage reduction from the OA baseline.
3.  **Robust OA Solve**: Replaced the unstable `solve()` call in `regulate` with a robust solver sequence (SSPRK432 -> Rosenbrock23 -> Tsit5) to ensure the baseline is calculated correctly.

**Result**:
*   The revenue curves now exhibit the expected hump shape for both Effort and Yield targets.
*   The mechanism is robust to parameter changes and correctly enforces scarcity.
