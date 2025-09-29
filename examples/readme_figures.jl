#!/usr/bin/env julia
# Generate example figures used by README

using Random
Random.seed!(1234)

if !isdefined(Main, :SEDist)
    include(joinpath(@__DIR__, "..", "SEDist.jl"))
end
const S = Main.SEDist

import CairoMakie
CairoMakie.activate!()

outdir = joinpath(@__DIR__, "figures")
isdir(outdir) || mkpath(outdir)

# 1) Phase + incomes for baseline
N = 100
s = S.scenario(S.base(N=N))
sol = S.sim(s)

fig1 = Figure(size=(900, 420))
ax1 = Axis(fig1[1, 1])
ax2 = Axis(fig1[1, 2])
phase_plot!(ax1, sol)
incomes_plot!(ax2, sol)
save(joinpath(outdir, "readme_phase_incomes.png"), fig1)

# 2) Dependency graph for a simple context
ctx = (
    N = N,
    q = S.sed(min=1/N, max=1/N, normalize=true),
    w = S.sed(min=0.2, max=0.4),
    K = 2.0,
    w̃ = S.sed(min=0.1, max=1.0, dependency_fun="q .* w ./ K .+ sed"),
    ū  = S.sed(dependency_fun="q ./ w̃"),
)
S.dist!(ctx)
fig2 = S.dependency_graph_plot(ctx)
save(joinpath(outdir, "readme_dep_graph.png"), fig2)

println("README figures saved to ", outdir)
