#!/usr/bin/env julia
# Demo: macro-based dependent distributions with SEDist.Context and @dep

using Random
Random.seed!(42)

include(joinpath(@__DIR__, "..", "SEDist.jl"))
using .SEDist

const N = 100

ctx = Context((
    q   = sed(min=1/N, max=1/N, normalize=true),
    w   = sed(min=0.2, max=0.4),
    K   = 2.0,
    w̃   = @dep (q, w, K) -> q .* w ./ K .+ sed(min=0.05, max=0.10),
    ubar = @dep (q, w̃)    -> q ./ w̃,
))

dist!(ctx; N=N)

println("w̃ summary: min=$(minimum(ctx[:w̃])) max=$(maximum(ctx[:w̃]))")
println("ū summary:  min=$(minimum(ctx[:ubar])) max=$(maximum(ctx[:ubar]))")

# Optional: run a quick simulation using realized distributions
s = scenario(base(N=N);
            w̃ = sed(data=ctx[:w̃]),
            ū = sed(data=ctx[:ubar]))
sol = sim(s)
println("final resource level y* = ", round(sol.u[end][end], digits=3))

