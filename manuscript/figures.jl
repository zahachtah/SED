#!/usr/bin/env julia
# Reproducible figure generation for the manuscript

using Random
Random.seed!(42)

if !isdefined(Main, :SED)
    include(joinpath(@__DIR__, "..", "SED.jl"))
end
const S = Main.SED

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
    q = S.dist(min=1/N, max=1/N, normalize=true),
    w = S.dist(min=0.2, max=0.4),
    K = 2.0,
    w̃ = S.dist(min=0.1, max=1.0, dependency_fun="q .* w ./ K .+ sed"),
    ū  = S.dist(dependency_fun="q ./ w̃"),
)
S.sample!(ctx)
fig2 = S.dependency_graph_plot(ctx)
save(joinpath(outdir, "dependency_graph.png"), fig2)

println("Figures written to: ", outdir)

# =====================
# Publication Figures
# =====================

"""
    policy_outcomes_figure(; s= S.base(N=100), order=false, goal=:Gov)

Build a multi‑panel figure comparing key policies at their optimal regulation
for a selected goal (default: :Gov). Panels show phase plots and incomes.
"""
function policy_outcomes_figure(; s= S.base(N=100), order=false, goal=:Gov)
    # Baseline distributions
    N = s.N
    w = S.dist(min=0.2, max=0.4)
    q = S.dist(min=1/N, max=1/N, normalize=true)
    S.sample!(w, N)
    S.sample!(q, N)
    w̃ = S.dist(min=0.1, max=1.0, dependency_fun = "q .* w .+ independent")
    ū  = S.dist(dependency_fun = "q")
    S.sample!(w̃, N; context=(; s..., w, q))
    S.sample!(ū,  N; context=(; s..., w, q))

    # Build comparable policies
    OA   = S.scenario(S.base(N=N); w̃, ū, title="Open Access")
    EUR  = S.scenario(S.base(N=N); w̃, ū, policy="Exclusive Use Rights", reverse=true,  title="hi w̃ excluded")
    EURf = S.scenario(S.base(N=N); w̃, ū, policy="Exclusive Use Rights", reverse=false, title="low w̃ excluded")
    TUR  = S.scenario(S.base(N=N); w̃, ū, policy="Tradable Use Rights",  policy_target=:effort, market_rate=0.05, title="effort")
    TURy = S.scenario(S.base(N=N); w̃, ū, policy="Tradable Use Rights",  policy_target=:yield,  market_rate=0.05, title="yield")
    PA   = S.scenario(S.base(N=N); w̃, ū, policy="Protected Area", m=0.3, title="PA")

    pols = [OA, EUR, EURf, TUR, TURy, PA]

    # Optimize regulation per policy for selected goal
    function optimize_goal(p)
        R = S.regulation_scan(p)
        g = R.RR .^ 0.5 .* R.ToR .^ 1.0 .* (1 .- R.GI) .^ 0.0 .* R.EH .^ 0.0
        opt = argmax(goal == :Gov ? g : R[goal])
        (reg=R.r[opt], idx=opt)
    end

    opts = optimize_goal.(pols)
    sols = [S.sim(p, regulation=o.reg) for (p, o) in zip(pols, opts)]

    # Assemble figure 2 rows x 3 cols
    f = Figure(size=(1000, 800))
    for (i, sol) in enumerate(sols)
        r = div(i-1, 3) + 1
        c = mod(i-1, 3) + 1
        ax1 = Axis(f[2r-1, c], title = sol.prob.p.title)
        ax2 = Axis(f[2r,   c])
        S.phase_plot!(ax1, sol)
        S.incomes_plot!(ax2, sol; order)
    end
    f
end

"""
    regscan_figure(; s=S.base(N=100), outcomes=[:RR,:ToR,:GI,:EH,:RI,:Gov])

Create a grid figure showing outcomes vs regulation for a standard policy set.
Marks the optimal regulation point per policy/outcome.
"""
function regscan_figure(; s=S.base(N=100), outcomes=[:RR,:ToR,:GI,:EH,:RI,:Gov])
    N = s.N
    w = S.dist(min=0.2, max=0.4); q = S.dist(min=1/N, max=1/N, normalize=true)
    S.sample!(w, N); S.sample!(q, N)
    w̃ = S.dist(min=0.1, max=1.0, dependency_fun = "q .* w .+ independent"); ū  = S.dist(dependency_fun = "q")
    S.sample!(w̃, N; context=(; s..., w, q)); S.sample!(ū, N; context=(; s..., w, q))

    policies = [
        S.scenario(S.base(N=N); w̃, ū, policy="Exclusive Use Rights", reverse=true,  name="EUR_hi"),
        S.scenario(S.base(N=N); w̃, ū, policy="Exclusive Use Rights", reverse=false, name="EUR_lo"),
        S.scenario(S.base(N=N); w̃, ū, policy="Tradable Use Rights",  policy_target=:effort, market_rate=0.05, name="TUR_effort"),
        S.scenario(S.base(N=N); w̃, ū, policy="Tradable Use Rights",  policy_target=:yield,  market_rate=0.05, name="TUR_yield"),
        S.scenario(S.base(N=N); w̃, ū, policy="Protected Area", m=0.3, name="PA_03"),
        S.scenario(S.base(N=N); w̃, ū, policy="Protected Area", m=0.5, name="PA_05"),
    ]

    scans = [S.regulation_scan(p) for p in policies]
    f = Figure(size=(1100, 900))
    for (i, rs) in enumerate(scans)
        for (j, o) in enumerate(outcomes)
            ax = Axis(f[j, i])
            lines!(ax, rs.r, rs[o], color=:black, linewidth=2)
            # mark optimum
            osym = Symbol("o" * String(o))
            idx = rs[osym]
            scatter!(ax, [rs.r[idx]], [rs[o][idx]]; color=:red)
        end
    end
    f
end

# Save publication‑style figures (filenames indicative; adjust as needed)
fig_pol = policy_outcomes_figure()
save(joinpath(outdir, "figure_policies.png"), fig_pol)

fig_scan = regscan_figure()
save(joinpath(outdir, "figure_regscan.png"), fig_scan)
