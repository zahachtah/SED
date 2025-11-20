using Statistics

# Open Access policy primitives and scenario builders moved here to keep SED_core.jl focused

# Base primitives
base_γ(x, p, t) = hasproperty(p, :w̃) && hasproperty(p.w̃, :data) ? p.w̃.data : p.w̃
base_μ(x, p, t) = hasproperty(p, :ū) && hasproperty(p.ū, :data) ? p.ū.data : p.ū
base_ϕ(dx, x, p, t) = nothing

# Master functions that iterate over policies
function master_γ(x, p, t)
    val = base_γ(x, p, t)
    if hasproperty(p, :policies)
        for pol in p.policies
            if hasproperty(pol, :γ)
                val = pol.γ(val, x, p, t)
            end
        end
    end
    return val
end

function master_μ(x, p, t)
    val = base_μ(x, p, t)
    if hasproperty(p, :policies)
        for pol in p.policies
            if hasproperty(pol, :μ)
                val = pol.μ(val, x, p, t)
            end
        end
    end
    return val
end

function master_ϕ(dx, x, p, t)
    base_ϕ(dx, x, p, t)
    if hasproperty(p, :policies)
        for pol in p.policies
            if hasproperty(pol, :ϕ)
                pol.ϕ(dx, x, p, t)
            end
        end
    end
end

regulate(p, f) = p

function scenario(p; kwargs...)
    # Initialize with empty policies list and master functions
    temp = (; p..., policy="Open Access", policies=Any[],
        γ=master_γ, μ=master_μ, ϕ=master_ϕ, regulate=regulate, kwargs...)
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

# Minimal policy functions retained for reference; legacy implementation archived in archive/legacy_dist_block.jl

# Legacy distribution definitions moved to archive/legacy_dist_block.jl for reference.

# The modular Dist type now lives in src/SED/Core/Dist.jl

