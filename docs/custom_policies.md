# Custom Policies

To create a new policy in SED, you define a struct that subtypes `AbstractPolicy` and implement the necessary dispatch methods. This allows your policy to integrate seamlessly with the simulation engine.

## 1. Define the Struct

Define a struct that holds any parameters your policy needs. It must subtype `AbstractPolicy`.

```julia
using SED

struct MyPolicy <: AbstractPolicy
    tax_rate::Float64
end
```

## 2. Implement Methods

You need to extend the following functions from `SED`. Note that `x` is the state vector, `p` is the scenario (NamedTuple), and `t` is time.

### `cost`
Modifies the cost of effort. The base cost (usually `w̃`) is passed as `val`.

```julia
import SED: cost

function cost(val, x, p, t, pol::MyPolicy)
    # Example: Add a tax
    return val .+ pol.tax_rate
end
```

### `limit`
Modifies the effort limit (capacity). The base limit (usually `ū`) is passed as `val`.

```julia
import SED: limit

function limit(val, x, p, t, pol::MyPolicy)
    # Example: No change to limit
    return val
end
```

### `dynamics`
Defines the derivatives for any extra state variables introduced by your policy.
If your policy doesn't add state variables, you can omit this (it falls back to doing nothing).

```julia
import SED: dynamics

function dynamics(dx, x, p, t, pol::MyPolicy)
    # Example: No extra dynamics
    return nothing
end
```

### `regulate`
Applies a regulation level `f` (0 to 1) to the scenario. This is called before the simulation starts. You should return a new scenario (usually using `change`).

```julia
import SED: regulate, change

function regulate(s, f, pol::MyPolicy)
    # Example: Scale tax rate by regulation level
    new_tax = pol.tax_rate * f
    new_pol = MyPolicy(new_tax)
    return change(s, policy=new_pol, regulation=f)
end
```

## 3. Use It

You can now use your custom policy in a scenario.

```julia
pol = MyPolicy(0.1)
s = scenario(base(), policy=pol)
sol = sim(s, regulation=0.5)
```

## Advanced: Adding State Variables

If your policy needs extra state variables (like the market price in TUR), you need to handle `u0` initialization in `sim` (currently requires modifying `src/model.jl` or using a workaround) and implement `dynamics` to update `dx`.

For now, adding extra state variables requires modifying `src/model.jl` to recognize your policy type in `sim_init` and `sim`. We plan to make this more modular in the future.
