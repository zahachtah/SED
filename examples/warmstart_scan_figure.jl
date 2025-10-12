#!/usr/bin/env julia
# Generate a simple scan figure using warm-started regulation scans

if !isdefined(Main, :SED)
    include(joinpath(@__DIR__, "..", "SED.jl"))
end
using .SED
using CairoMakie
CairoMakie.activate!()

outdir = joinpath(@__DIR__, "figures")
isdir(outdir) || mkpath(outdir)

N = 100
s = scenario(base(N=N))
R = regulation_scan(s; m=50, warmstart=:chain)

fig = Figure(size=(700, 360))
ax = Axis(fig[1, 1], xlabel="regulation", ylabel="Total income (ToR)")
lines!(ax, R.r, R.ToR, color=:darkorange, linewidth=2)
opt = R.oToR
scatter!(ax, [R.r[opt]], [R.ToR[opt]], color=:black)
text!(ax, R.r[opt], R.ToR[opt], text="opt", align=(:left, :bottom))
save(joinpath(outdir, "warmstart_scan.png"), fig)
println("Saved ", joinpath(outdir, "warmstart_scan.png"))

