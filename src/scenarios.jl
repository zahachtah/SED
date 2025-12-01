using Statistics

# Open Access policy primitives and scenario builders moved here to keep SED_core.jl focused

# Base primitives
base_cost(x, p, t) = hasproperty(p, :w̃) && hasproperty(p.w̃, :data) ? p.w̃.data : p.w̃
base_limit(x, p, t) = hasproperty(p, :ū) && hasproperty(p.ū, :data) ? p.ū.data : p.ū
base_dynamics(dx, x, p, t) = nothing

# Master functions that dispatch to policy implementation
function master_cost(x, p, t)
    val = base_cost(x, p, t)
    return cost(val, x, p, t) # Dispatch to policies.jl
end

function master_limit(x, p, t)
    val = base_limit(x, p, t)
    return limit(val, x, p, t) # Dispatch to policies.jl
end

function master_dynamics(dx, x, p, t)
    base_dynamics(dx, x, p, t)
    dynamics(dx, x, p, t) # Dispatch to policies.jl
end



function scenario(p; kwargs...)
    # Handle policy argument: String -> Struct
    pol_arg = get(kwargs, :policy, "Open Access")

    # If it's already a struct, use it. If string, convert.
    pol = if pol_arg isa AbstractPolicy
        pol_arg
    elseif pol_arg == "Open Access"
        OpenAccess()
    elseif pol_arg == "Tradable Use Rights"
        target = get(kwargs, :policy_target, :effort)
        market_rate = get(kwargs, :market_rate, 0.05)
        buyer_bias = get(kwargs, :buyer_bias, 0.0)
        historical = get(kwargs, :historical_use_rights, false)
        TradableUseRights(target, Float64(market_rate), Float64(buyer_bias), historical)
    elseif pol_arg == "Exclusive Use Rights"
        selector = get(kwargs, :selector, :top)
        reverse = get(kwargs, :reverse, false)
        ExclusiveUseRights(selector, reverse)
    elseif pol_arg == "Protected Area"
        m = get(kwargs, :m, 0.3)
        ProtectedArea(Float64(m))
    elseif pol_arg == "Protected Area Two Pop"
        m = get(kwargs, :m, 0.3)
        ProtectedAreaTwoPop(Float64(m))
    elseif pol_arg == "Economic Incentives"
        target = get(kwargs, :policy_target, [:cost, :limit])
        method = get(kwargs, :policy_method, :multiplicative)
        # Ensure target is a vector
        target_vec = target isa Symbol ? [target] : target
        EconomicIncentives(target_vec, method)
    elseif pol_arg == "Development"
        μ_value = get(kwargs, :μ_value, 0.5)
        γ_value = get(kwargs, :γ_value, 0.5)
        Development(Float64(μ_value), Float64(γ_value))
    else
        # Fallback or Error
        # For now, default to OpenAccess if unknown string, or error?
        # Better to error or warn. But let's assume OpenAccess for safety if not matched?
        # No, better to error to catch typos.
        if pol_arg isa String
            error("Unknown policy string: $pol_arg")
        end
        pol_arg # Assume it's a custom struct
    end

    # Remove policy-specific kwargs that are now in the struct to avoid clutter?
    # Or keep them for backward compatibility if something accesses p.market_rate?
    # The new policies.jl uses pol.market_rate.
    # But existing code might access p.market_rate.
    # Safe to keep them in kwargs.

    # Construct the scenario
    # We override :policy with the struct
    temp = (; p...,
        cost=master_cost, limit=master_limit, dynamics=master_dynamics, regulate=regulate,
        kwargs...,
        policy=pol)

    return (; temp...)
end

function base(; N=100, sigma=0.0, random=false)
    p = (; N,
        α=0.1,
        w̃=dist(min=0.1, max=1.0, distribution=LogNormal, random=random),
        ū=dist(mean=1.0, sigma=sigma, normalize=true, random=random),
        R=ones(N))
    return scenario(p)
end

function high_impact(; N=100, sigma=0.0)
    p = (; N, α=0.1,
        w̃=dist(min=0.01, max=1.0, distribution=LogNormal),
        ū=dist(mean=2.0, sigma=sigma, normalize=true),
        R=ones(N))
    return scenario(p)
end

function low_impact(; N=100, sigma=0.0)
    p = (; N, α=0.1,
        w̃=dist(min=0.01, max=0.6, distribution=LogNormal),
        ū=dist(mean=0.5, sigma=sigma, normalize=true),
        R=ones(N))
    return scenario(p)
end

function high_incentives(; N=100, sigma=0.0)
    p = (; N, α=0.1,
        w̃=dist(min=0.3, max=0.7, distribution=LogNormal),
        ū=dist(mean=1.0, sigma=sigma, normalize=true),
        R=ones(N))
    return scenario(p)
end
