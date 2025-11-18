using Statistics

# Open Access policy primitives and scenario builders moved here to keep SED_core.jl focused

function γ(x, p, t)
    return hasproperty(p, :w̃) && hasproperty(p.w̃, :data) ? p.w̃.data : p.w̃
end
function μ(x, p, t)
    return hasproperty(p, :ū) && hasproperty(p.ū, :data) ? p.ū.data : p.ū
end
ϕ(dx, x, p, t) = nothing
regulate(p, f) = p

function scenario(p; kwargs...)
    temp = (; p..., policy="Open Access", γ=γ, μ=μ, ϕ=ϕ, regulate=regulate, kwargs...)
    return (; temp...)
end

function base(; N=100, sigma=0.0, random=false)
    (; N,
        α=0.1,
        w̃=dist(min=0.1, max=1.0, distribution=LogNormal, random=random),
        ū=dist(mean=1.0, sigma=sigma, normalize=true, random=random),
        R=ones(N), γ, μ, ϕ, regulate, policy="Open Access")
end

function high_impact(; N=100, sigma=0.0)
    (; N, α=0.1,
        w̃=dist(min=0.01, max=1.0, distribution=LogNormal),
        ū=dist(mean=2.0, sigma=sigma, normalize=true),
        R=ones(N), γ, μ, ϕ, regulate, policy="Open Access")
end

function low_impact(; N=100, sigma=0.0)
    (; N, α=0.1,
        w̃=dist(min=0.01, max=0.6, distribution=LogNormal),
        ū=dist(mean=0.5, sigma=sigma, normalize=true),
        R=ones(N), γ, μ, ϕ, regulate, policy="Open Access")
end

function high_incentives(; N=100, sigma=0.0)
    (; N, α=0.1,
        w̃=dist(min=0.3, max=0.7, distribution=LogNormal),
        ū=dist(mean=1.0, sigma=sigma, normalize=true),
        R=ones(N), γ, μ, ϕ, regulate, policy="Open Access")
end

# Minimal policy functions retained for reference; legacy implementation archived in archive/legacy_dist_block.jl

# Legacy distribution definitions moved to archive/legacy_dist_block.jl for reference.

# The modular Dist type now lives in src/SED/Core/Dist.jl

