#!/usr/bin/env julia
# Generate example figures used by README

using Random
Random.seed!(1234)

if !isdefined(Main, :SED)
    include(joinpath(@__DIR__, "..", "SED.jl"))
end
const S = Main.SED

using CairoMakie
CairoMakie.activate!()

# Ensure latest visualization helpers are available even if SED was loaded earlier
if !isdefined(S, :dist_plot_compare)
    Base.include(S, joinpath(@__DIR__, "..", "SED_visualizations.jl"))
end

outdir = joinpath(@__DIR__, "figures")
isdir(outdir) || mkpath(outdir)

# 1) Phase + incomes for baseline
N = 100
s = S.scenario(S.base(N=N))
sol = S.sim(s)

fig1 = Figure(size=(900, 420))
ax1 = Axis(fig1[1, 1])
ax2 = Axis(fig1[1, 2])
S.phase_plot!(ax1, sol)
S.incomes_plot!(ax2, sol)
save(joinpath(outdir, "readme_phase_incomes.png"), fig1)

# 2) Dependency graph for a simple context
ctx = (
    N = N,
    q = S.dist(min=1/N, max=1/N, normalize=true),
    w = S.dist(min=0.2, max=0.4),
    K = 2.0,
    w̃ = S.dist(min=0.1, max=1.0, dependency_fun="q .* w ./ K .+ sed"),
    ū  = S.dist(dependency_fun="q ./ w̃"),
)
S.sample!(ctx)
fig2 = S.dependency_graph_plot(ctx)
save(joinpath(outdir, "readme_dep_graph.png"), fig2)

# 3) Random vs non-random sampling
q_nr = S.dist(min=1/N, max=1/N, normalize=true)
q_r  = S.dist(min=1/N, max=1/N, normalize=true)
S.sample!(q_nr, N; random=false)
S.sample!(q_r,  N; random=true)
fig3 = Figure(size=(800, 300))
ax3a = Axis(fig3[1,1], title = "non-random (quantiles)")
ax3b = Axis(fig3[1,2], title = "random (samples)")
lines!(ax3a, 1:N, sort(q_nr.data))
lines!(ax3b, 1:N, sort(q_r.data))
save(joinpath(outdir, "readme_sampling_compare.png"), fig3)

# 4) Γ and Φ vs y for baseline
y = range(0, 1, length=200)
fig4 = Figure(size=(800, 300))
gx = Axis(fig4[1,1], title = "Γ(y)")
hx = Axis(fig4[1,2], title = "Φ(y)")
lines!(gx, y, S.Γ.(y, Ref(sol.prob.p), x=sol.u[end-1]))
lines!(hx, y, S.Φ.(y, Ref(sol.prob.p)))
save(joinpath(outdir, "readme_gamma_phi.png"), fig4)

# 5) Distribution gallery (Uniform, LogNormal, Normal, Exponential, Bernoulli)
N2 = 100
gallery = [
    ("Uniform",     () -> S.dist(min=0.1, max=0.9, distribution=Uniform)),
    ("LogNormal",   () -> S.dist(min=0.1, max=1.0, distribution=LogNormal)),
    ("Normal",      () -> S.dist(mean=0.5, sigma=0.1, distribution=Normal)),
    ("Exponential", () -> S.dist(mean=0.5, sigma=0.0, distribution=Exponential)),
    ("Bernoulli",   () -> S.dist(mean=0.5, distribution=Bernoulli)),
]
for (name, make) in gallery
    try
        f = S.dist_plot_compare(make, N2; title=name)
        save(joinpath(outdir, "readme_dist_$(lowercase(name)).png"), f)
    catch err
        @warn "Could not render gallery item" name err
    end
end

println("README figures saved to ", outdir)
