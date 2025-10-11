#!/usr/bin/env julia
# Reproducible figure generation for the manuscript

using Random
Random.seed!(42)


# Choose a Makie backend (uncomment your preference)
using CairoMakie
CairoMakie.activate!()

# Output folder
outdir = joinpath(@__DIR__, "figures")
isdir(outdir) || mkpath(outdir)

# Example 1: Phase + incomes for a baseline scenario
N = 100
s = scenario(S.base(N=N))
sol = sim(s)

fig1 = Figure(size=(900, 420))
ax1 = Axis(fig1[1, 1])
ax2 = Axis(fig1[1, 2])
phase_plot!(ax1, sol)
incomes_plot!(ax2, sol)
save(joinpath(outdir, "baseline_phase_incomes.png"), fig1)

# Example 2: Dependency graph for a simple dependent context
ctx = (
    N=N,
    q=dist(min=1 / N, max=1 / N, normalize=true),
    w=dist(min=0.2, max=0.4),
    K=2.0,
    w̃=dist(min=0.1, max=1.0, dependency_fun="q .* w ./ K .+ sed"),
    ū=dist(dependency_fun="q ./ w̃"),
)
sample!(ctx)
fig2 = dependency_graph_plot(ctx)
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
function policy_outcomes_figure(; s=S.base(N=100), order=false, goal=:Gov)
    # Baseline distributions
    N = s.N
    w = S.dist(min=0.2, max=0.4)
    q = S.dist(min=1 / N, max=1 / N, normalize=true)
    sample!(w, N)
    sample!(q, N)
    w̃ = S.dist(min=0.1, max=1.0, dependency_fun="q .* w .+ independent")
    ū = S.dist(dependency_fun="q")
    S.sample!(w̃, N; context=(; s..., w, q))
    S.sample!(ū, N; context=(; s..., w, q))

    # Build comparable policies
    OA = S.scenario(S.base(N=N); w̃, ū, title="Open Access")
    EUR = S.scenario(S.base(N=N); w̃, ū, policy="Exclusive Use Rights", reverse=true, title="hi w̃ excluded")
    EURf = S.scenario(S.base(N=N); w̃, ū, policy="Exclusive Use Rights", reverse=false, title="low w̃ excluded")
    TUR = S.scenario(S.base(N=N); w̃, ū, policy="Tradable Use Rights", policy_target=:effort, market_rate=0.05, title="effort")
    TURy = S.scenario(S.base(N=N); w̃, ū, policy="Tradable Use Rights", policy_target=:yield, market_rate=0.05, title="yield")
    PA = S.scenario(S.base(N=N); w̃, ū, policy="Protected Area", m=0.3, title="PA")

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
        r = div(i - 1, 3) + 1
        c = mod(i - 1, 3) + 1
        ax1 = Axis(f[2r-1, c], title=sol.prob.p.title)
        ax2 = Axis(f[2r, c])
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
function regscan_figure(; s=base(N=100), outcomes=[:RR, :ToR, :GI, :EH, :RI, :Gov])
    N = s.N
    w = S.dist(min=0.2, max=0.4)
    q = S.dist(min=1 / N, max=1 / N, normalize=true)
    S.sample!(w, N)
    S.sample!(q, N)
    w̃ = S.dist(min=0.1, max=1.0, dependency_fun="q .* w .+ independent")
    ū = S.dist(dependency_fun="q")
    S.sample!(w̃, N; context=(; s..., w, q))
    S.sample!(ū, N; context=(; s..., w, q))

    policies = [
        S.scenario(S.base(N=N); w̃, ū, policy="Exclusive Use Rights", reverse=true, name="EUR_hi"),
        S.scenario(S.base(N=N); w̃, ū, policy="Exclusive Use Rights", reverse=false, name="EUR_lo"),
        S.scenario(S.base(N=N); w̃, ū, policy="Tradable Use Rights", policy_target=:effort, market_rate=0.05, name="TUR_effort"),
        S.scenario(S.base(N=N); w̃, ū, policy="Tradable Use Rights", policy_target=:yield, market_rate=0.05, name="TUR_yield"),
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


function figure3(; s=high_impact())
    no_change = :lightgray
    base_w̃ = 0.3


    f = Figure(size=(900, 600))
    w̃_sigma_plot = Axis(f[2, 1])
    w̃_median_plot = Axis(f[3, 1])
    ū_mean_plot = Axis(f[2, 2])
    ū_cor_plot = Axis(f[3, 2])
    α_plot = Axis(f[2, 3])
    inc_plot = Axis(f[3, 3], xlabel="time  →", ylabel="actor's w̃", yaxisposition=:right, xscale=log10)



    [hidespines!(a) for a in [w̃_sigma_plot, w̃_median_plot, ū_mean_plot, ū_cor_plot, α_plot, inc_plot]]
    [hidedecorations!(a) for a in [w̃_sigma_plot, w̃_median_plot, ū_mean_plot, ū_cor_plot, α_plot]]
    #hideydecorations!(inc_plot)


    s = scenario(s, w̃=dist(median=0.3, sigma=0.8, distribution=LogNormal))
    #[phase_plot!(a,sim(s)) for a in [α_plot]]

    phase_plot!(w̃_sigma_plot, sim(scenario(s, w̃=dist(median=0.5, sigma=0.8, distribution=LogNormal))), impact_line_color=no_change)
    phase_plot!(w̃_sigma_plot, sim(scenario(s, w̃=dist(median=0.5, sigma=0.3, distribution=LogNormal))), impact_line_color=no_change, show_exploitation=false)
    phase_plot!(w̃_sigma_plot, sim(scenario(s, w̃=dist(median=0.5, sigma=0.0, distribution=LogNormal))), impact_line_color=no_change, show_exploitation=false)
    arrow_arc_deg!(w̃_sigma_plot, [0.5, 0.5], 0.4, 0, 60)
    #Γ_plot!(w̃_sigma_plot,sim(s))
    text!(w̃_sigma_plot, 0.7, 0.5, text="Increasing\nInequality")
    text!(w̃_sigma_plot, 0.1, 0.5, text="No change in\nmedian Inequality")
    text!(w̃_sigma_plot, 0.55, 0.3, text="leads to\noverexploitation")
    text!(w̃_sigma_plot, 0.02, 0.91, text="a)")

    phase_plot!(w̃_median_plot, sim(scenario(s, w̃=dist(min=0.1, max=0.5, distribution=LogNormal))), impact_line_color=no_change)
    phase_plot!(w̃_median_plot, sim(scenario(s, w̃=dist(min=0.3, max=0.7, distribution=LogNormal))), impact_line_color=no_change, show_exploitation=false)
    phase_plot!(w̃_median_plot, sim(scenario(s, w̃=dist(min=0.5, max=0.9, distribution=LogNormal))), impact_line_color=no_change, show_exploitation=false)
    #Γ_plot!(w̃_median_plot,sim(s))
    text!(w̃_median_plot, 0.7, 0.4, text="Increasing\nIncentives")
    arrows2d!(w̃_median_plot, [0.24], [0.5], [0.4], [0.0])
    text!(w̃_median_plot, 0.02, 0.91, text="b)")

    phase_plot!(ū_mean_plot, sim(s), incentive_line_color=no_change)
    Φ_plot!(ū_mean_plot, sim(scenario(s, ū=dist(mean=0.5, sigma=0.0, normalize=true))))
    Φ_plot!(ū_mean_plot, sim(scenario(s, ū=dist(mean=1.0, sigma=0.0, normalize=true))))
    Φ_plot!(ū_mean_plot, sim(scenario(s, ū=dist(mean=2.0, sigma=0.0, normalize=true))))
    text!(ū_mean_plot, 0.5, 0.15, text="Increasing\nImpact")
    arrow_arc_deg!(ū_mean_plot, [1.0, 0.0], 0.5, -25, -60, flip_arrow=true)
    attractor_plot!(ū_mean_plot, sim(scenario(s, ū=dist(mean=2.0, sigma=0.0, normalize=true))), color=:black, markersize=12)
    attractor_plot!(ū_mean_plot, sim(scenario(s, ū=dist(mean=1.0, sigma=0.0, normalize=true))), color=:black, markersize=12)
    attractor_plot!(ū_mean_plot, sim(scenario(s, ū=dist(mean=0.5, sigma=0.0, normalize=true))), color=:black, markersize=12)
    text!(ū_mean_plot, 0.02, 0.91, text="c)")

    phase_plot!(ū_cor_plot, sim(s), incentive_line_color=no_change)
    Φ_plot!(ū_cor_plot, sim(scenario(s, ū=dist(mean=1.2, sigma=4.0, normalize=true))))
    Φ_plot!(ū_cor_plot, sim(scenario(s, ū=dist(mean=1.0, sigma=0.0, normalize=true))), color=no_change)
    Φ_plot!(ū_cor_plot, sim(scenario(s, ū=dist(mean=1.0, sigma=-4.0, normalize=true))))
    attractor_plot!(ū_cor_plot, sim(scenario(s, ū=dist(mean=2.0, sigma=4.0, normalize=true))), color=:black, markersize=12)
    attractor_plot!(ū_cor_plot, sim(scenario(s, ū=dist(mean=2.0, sigma=0.0, normalize=true))), color=:black, markersize=12)
    attractor_plot!(ū_cor_plot, sim(scenario(s, ū=dist(mean=2.0, sigma=-4.0, normalize=true))), color=:black, markersize=12)
    text!(ū_cor_plot, 0.4, 0.6, text="Incentives and Impact:\nnegatively correlated")
    text!(ū_cor_plot, 0.2, 0.07, text="positively\ncorrelated")
    text!(ū_cor_plot, 0.325, 0.35, text="uncorrelated")
    text!(ū_cor_plot, 0.1, 0.75, text="Actually, make them \nhave same attractor!\n check if youcan make correlations from \ndependencies")
    text!(ū_cor_plot, 0.02, 0.91, text="d)")

    phase_plot!(α_plot, sim(s), impact_line_color=no_change, incentive_line_color=no_change, show_trajectory=true, trajectory_color=:darkorange)
    text!(α_plot, 0.1, 0.85, text="behavioral response fast", color=:darkorange)
    phase_plot!(α_plot, sim(scenario(s, α=0.01)), impact_line_color=no_change, incentive_line_color=no_change, show_trajectory=true, show_exploitation=false, trajectory_color=:crimson)
    text!(α_plot, 0.35, 0.55, text="behavioral response slow", color=:crimson)
    text!(α_plot, 0.02, 0.91, text="e)")


    #incomes_plot!(inc_plot,sim(s))
    a = heatmap!(inc_plot, sim(scenario(s, α=0.05)).t .+ 1, s.w̃, sim(scenario(s, α=0.05))[1:100, :]', colormap=cgrad([:white, :darkorange]))
    elements = [[PolyElement(color=:darkorange, strokecolor=:lightgray, strokewidth=1)], [PolyElement(color=:darkorange, strokecolor=:lightgray, strokewidth=1, alpha=0.5)], [PolyElement(color=:white, strokecolor=:lightgray, strokewidth=1)]]
    axislegend(inc_plot, elements, ["Full resource use", "Half resource use", "No resource use"], framevisible=false, "Individual actor's\nresource use over time", rowgap=0)
    #xlims!(inc_plot,(0.0,10.0))
    ylims!(inc_plot, (0.0, 1.0))
    text!(inc_plot, 1.3, 0.91, text="f)")
    #[lines!(inc_plot,sim(s).t,sim(s)[i,:], label="w̃=$(round(s.w̃[i],digits=2))", color=cgrad(:viridis)[Int64(round(i/100*255))]) for i in 1:2:100]
    #xlims!(inc_plot,(0.0,20.0))
    #axislegend(inc_plot,framevisible=false)

    w = SED.sample!(dist(median=0.002, sigma=0.3, distribution=LogNormal), 100)
    q1 = SED.sample!(dist(median=0.9, sigma=0.4, distribution=Uniform, normalize=true), 100)
    q2 = SED.sample!(dist(median=1.3, sigma=1.4, distribution=Uniform, normalize=true), 100)
    #scatter!(qw_plot,w,w, color=no_change)


    function incometext(sol; regulation=false)
        income = incomes(sol)
        reg = " @" * string(round(haskey(sol.prob.p, :regulation) ? sol.prob.p.regulation : 0.0, digits=2))
        inc = "R:" * string(round(sum(income.resource), digits=2)) * "  T:" * string(round(sum(income.total), digits=2)) * "  G:" * string(round(income.gini, digits=2))
        return regulation ? inc * reg : inc
    end


    Label(f[1, 1], text="Incentives, w̃", tellwidth=false, font=:bold)
    Label(f[1, 2], text="Impact, ū", tellwidth=false, font=:bold)
    Label(f[1, 3], text="Dynamics, α", tellwidth=false, font=:bold)
    Label(f[0, 1:3], text="Effects of relational variable's distributions", tellwidth=false, font=:bold, fontsize=22)

    f

end

save("manuscript/figures/figure3.png", figure3())

function figureShift(; s=high_impact())
    no_change = :lightgray
    base_w̃ = 0.3


    f = Figure(size=(900, 300))

    qw_plot = Axis(f[1, 1], xlabel="alternative incomes, w", ylabel="efficiency, q")
    w̃_plot = Axis(f[1, 2], xlabel="alternative incomes, w", ylabel="Incentives w̃")
    qw_pp_plot = Axis(f[1, 3])
    IGL = f[1, 4] = GridLayout()
    qw_inc_plot1 = Axis(IGL[1, 1])
    qw_inc_plot2 = Axis(IGL[2, 1])

    [hidespines!(a) for a in [qw_plot, w̃_plot, qw_pp_plot, qw_inc_plot1, qw_inc_plot2]]
    [hidedecorations!(a) for a in [qw_inc_plot1, qw_inc_plot2, qw_pp_plot]]
    #hideydecorations!(inc_plot)


    s = scenario(s, w̃=dist(median=0.3, sigma=0.8, distribution=LogNormal))
    #[phase_plot!(a,sim(s)) for a in [α_plot]]

    w = SED.sample!(dist(median=0.002, sigma=0.3, distribution=LogNormal), 100)
    q1 = SED.sample!(dist(median=0.9, sigma=0.4, distribution=Uniform, normalize=true), 100)
    q2 = SED.sample!(dist(median=1.3, sigma=1.4, distribution=Uniform, normalize=true), 100)
    w = SED.sample!(dist(median=0.002, sigma=0.3, distribution=LogNormal), 100)
    q1 = SED.sample!(dist(median=0.9, sigma=0.4, distribution=Uniform, normalize=true), 100)
    q2 = SED.sample!(dist(median=1.3, sigma=1.4, distribution=Uniform, normalize=true), 100)
    #scatter!(qw_plot,w,w, color=no_change)
    scatter!(qw_plot, w, q1, color=no_change)
    scatter!(qw_plot, w, q2, color=:darkorange)
    #lines!(qw_plot,w, color=:black, linewidth=1)
    text!(qw_plot, 0.001, 0.017, text="Actors with high w get\ndisproportionately\nbetter access to\ntechnology")
    arrows2d!(qw_plot, [0.0038], [0.0125], [0], [0.005])
    ylims!(qw_plot, 0.0005, 0.03)

    scatter!(w̃_plot, w, w ./ q1, color=no_change)
    scatter!(w̃_plot, w, w ./ q2, color=:darkorange)
    text!(w̃_plot, 0.4, 0.1, text="Incentive\nshift", space=:relative)
    text!(w̃_plot, 0.1, 0.85, text=L"$$\tilde{w}≈\frac{w}{q}$$", space=:relative)
    arrows2d!(w̃_plot, [0.001], [0.14], [0.0013], [0])

    function incometext(sol; regulation=false)
        income = incomes(sol)
        reg = " @" * string(round(haskey(sol.prob.p, :regulation) ? sol.prob.p.regulation : 0.0, digits=2))
        inc = "R:" * string(round(sum(income.resource), digits=2)) * "  T:" * string(round(sum(income.total), digits=2)) * "  G:" * string(round(income.gini, digits=2))
        return regulation ? inc * reg : inc
    end

    sol1 = sim(scenario(base(), w̃=dist(data=w ./ q1), ū=dist(data=q1)))
    incomes_plot!(qw_inc_plot1, sol1, color=no_change)
    text!(qw_inc_plot1, 0.01, 0.8, text=incometext(sol1), space=:relative, fontsize=10)
    sol2 = sim(scenario(base(), w̃=dist(data=w ./ q2), ū=dist(data=q2)))
    incomes_plot!(qw_inc_plot2, sol2)
    text!(qw_inc_plot2, 0.1, 0.1, text="Income distribution shift", space=:relative, fontsize=12)
    println(incometext(sol2))
    text!(qw_inc_plot2, 0.01, 0.8, text=incometext(sol2), space=:relative, fontsize=10)
    phase_plot!(qw_pp_plot, sol1, incentive_line_color=no_change, impact_line_color=no_change)
    phase_plot!(qw_pp_plot, sol2)
    #=
        Label(f[1, 1], text="Incentives, w̃", tellwidth=false, tellheight=false, font=:bold)
        Label(f[1, 2], text="Impact, ū", tellwidth=false, tellheight=false, font=:bold)
        Label(f[1, 3], text="Dynamics, α", tellwidth=false, font=:bold)
        Label(f[0, 1:3], text="Effects of relational variable's distributions", tellwidth=false, tellheight=false, font=:bold, fontsize=22)
        Label(f[3, 1:3], text="Incentive shift driven by change in empirical model variables", tellheight=false, tellwidth=false, font=:bold, fontsize=22)
    =#
    f

end
