#!/usr/bin/env julia
# Reproducible figure generation for the manuscript

using Random
Random.seed!(42)

if !isdefined(Main, :SEDist)
    include(joinpath(@__DIR__, "..", "SEDist.jl"))
end
const S = Main.SEDist

# Choose a Makie backend (uncomment your preference)
using CairoMakie
CairoMakie.activate!()

# Output folder
outdir = joinpath(@__DIR__, "figures")
isdir(outdir) || mkpath(outdir)

# Example 1: Phase + incomes for a baseline scenario
N = 100
s = S.scenario(S.base(N=N))
sol = S.sim(s)

fig1 = Figure(size=(900, 420))
ax1 = Axis(fig1[1, 1])
ax2 = Axis(fig1[1, 2])
S.phase_plot!(ax1, sol)
S.incomes_plot!(ax2, sol)
save(joinpath(outdir, "baseline_phase_incomes.png"), fig1)

# Example 2: Dependency graph for a simple dependent context
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
save(joinpath(outdir, "dependency_graph.png"), fig2)

println("Figures written to: ", outdir)
