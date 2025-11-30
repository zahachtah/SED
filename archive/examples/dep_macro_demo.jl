#!/usr/bin/env julia
# Demo: macro-based dependent distributions with SEDist.Context and @dep

using Random
Random.seed!(42)

if !isdefined(Main, :SED)
    include(joinpath(@__DIR__, "..", "SED.jl"))
end
using .SED

const N = 100

ctx = (
    N = N,
    q   = dist(min=1/N, max=1/N, normalize=true),
    w   = dist(min=0.2, max=0.4),
    K   = 2.0,
    w̃   = dist(min=0.05, max=0.10, dependency_fun="q .* w ./ K .+ independent"),
    ubar = dist(dependency_fun="q ./ w̃"),
)

sample!(ctx)

println("w̃ summary: min=$(minimum(ctx.w̃)) max=$(maximum(ctx.w̃))")
println("ū summary:  min=$(minimum(ctx.ubar)) max=$(maximum(ctx.ubar))")

# Optional: run a quick simulation using realized distributions
s = scenario(base(N=N);
            w̃ = dist(data=ctx.w̃),
            ū = dist(data=ctx.ubar))
sol = sim(s)
println("final resource level y* = ", round(sol.u[end][end], digits=3))
