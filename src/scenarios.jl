using Statistics

# Open Access policy primitives and scenario builders moved here to keep SED_core.jl focused

# Base primitives
base_cost(x, p, t) = hasproperty(p, :w̃) && hasproperty(p.w̃, :data) ? p.w̃.data : p.w̃
base_limit(x, p, t) = hasproperty(p, :ū) && hasproperty(p.ū, :data) ? p.ū.data : p.ū
base_dynamics(dx, x, p, t) = nothing

# Master functions that dispatch to policy implementation
function master_cost(x, p, t)
    val = base_cost(x, p, t)
    if hasproperty(p, :policy) && p.policy != "Open Access"
        return cost(val, x, p, t) # Dispatch to policies.jl
    end
    return val
end

function master_limit(x, p, t)
    val = base_limit(x, p, t)
    if hasproperty(p, :policy) && p.policy != "Open Access"
        return limit(val, x, p, t) # Dispatch to policies.jl
    end
    return val
end

function master_dynamics(dx, x, p, t)
    base_dynamics(dx, x, p, t)
    if hasproperty(p, :policy) && p.policy != "Open Access"
        dynamics(dx, x, p, t) # Dispatch to policies.jl
    end
end



function scenario(p; kwargs...)
    # Initialize with default Open Access policy
    temp = (; p..., policy="Open Access",
        cost=master_cost, limit=master_limit, dynamics=master_dynamics, regulate=regulate, kwargs...)
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


