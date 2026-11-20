using CairoMakie
using Printf
using SED
using Statistics

CairoMakie.activate!()

const DARK = RGBf(0.11, 0.13, 0.16)
const MUTED = RGBf(0.43, 0.48, 0.57)
const GRID = RGBAf(0.12, 0.16, 0.20, 0.08)
const GRAY = RGBf(0.67, 0.70, 0.74)
const SHADE = RGBAf(0.0, 0.0, 0.0, 0.055)
const BLUE = RGBf(0.05, 0.39, 0.66)
const LIGHTBLUE = RGBf(0.52, 0.70, 0.90)
const ORANGE = RGBf(0.95, 0.43, 0.05)
const LIGHTORANGE = RGBf(1.00, 0.66, 0.32)
const GREEN = RGBf(0.10, 0.58, 0.18)
const LIGHTGREEN = RGBf(0.55, 0.82, 0.50)
const RED = RGBf(0.82, 0.12, 0.13)

withalpha(c, a) = RGBAf(c.r, c.g, c.b, a)
distdata(x) = hasproperty(x, :data) ? x.data : x

function style_phase_axis!(ax)
    ax.xgridcolor = GRID
    ax.ygridcolor = GRID
    ax.xticklabelcolor = MUTED
    ax.yticklabelcolor = MUTED
    ax.xlabelcolor = DARK
    ax.ylabelcolor = DARK
    ax.titlecolor = DARK
    ax.spinewidth = 0.8
    spine = RGBAf(0.12, 0.16, 0.20, 0.18)
    for side in (:bottomspinecolor, :leftspinecolor, :topspinecolor, :rightspinecolor)
        setproperty!(ax, side, spine)
    end
    ax.xticks = 0:0.5:1
    ax.yticks = 0:0.5:1
    xlims!(ax, 0, 1)
    ylims!(ax, 0, 1)
    return ax
end

function style_income_axis!(ax)
    ax.xgridvisible = false
    ax.ygridvisible = false
    ax.xticklabelsvisible = false
    ax.yticklabelsvisible = false
    ax.xticksvisible = false
    ax.yticksvisible = false
    ax.xlabelvisible = false
    ax.ylabelvisible = false
    ax.spinewidth = 0.0
    ax.titlealign = :left
    ax.titlesize = 14.5
    ax.titlegap = 3
    return ax
end

function style_compact_phase!(ax)
    style_phase_axis!(ax)
    ax.xlabel = "resource level, y"
    ax.ylabel = "Participation (share of all actors)"
    ax.xlabelsize = 12
    ax.ylabelsize = 12
    ax.xticklabelsize = 10
    ax.yticklabelsize = 10
    return ax
end

function figure_population(; N=140)
    threshold_dist = dist(distribution=LogNormal, min=0.055, max=0.94, random=false)
    impact_dist = dist(distribution=LogNormal, min=0.18, max=2.20, random=false)
    sample!(threshold_dist, N; random=false)
    sample!(impact_dist, N; random=false)
    thresholds = copy(threshold_dist.data)
    raw_impact = reverse(impact_dist.data)
    impacts = raw_impact ./ sum(raw_impact) .* 1.24
    s = scenario(base(N=N);
        α=0.05, w̃=dist(data=thresholds), ū=dist(data=impacts),
        opportunities=dist(data=thresholds), title="Open access")
    sample!(s; force=true)
    return s, thresholds, impacts
end

steady_index(sol) = max(1, length(sol.t) - 2)
steady_state(sol) = sol.u[steady_index(sol)]
steady_time(sol) = sol.t[steady_index(sol)]

function participation(sol)
    p = sol.prob.p
    x = steady_state(sol)
    limits = p.limit(x, p, steady_time(sol))
    return clamp(mean(clamp.(x[1:p.N] ./ limits, 0.0, 1.0)), 0.0, 1.0)
end

attractor(sol) = (clamp(steady_state(sol)[sol.prob.p.N+1], 0.0, 1.0), participation(sol))

function curves_for(sol; n=220)
    p = sol.prob.p
    x = steady_state(sol)
    t = steady_time(sol)
    y = collect(range(0.0, 1.0, length=n))
    # Supply the final market state as well as y for state-dependent policies.
    gamma = [Γ(yy, p; x=x, t=t) for yy in y]
    phi = [Φ(yy, p; x=x, t=t) for yy in y]
    return y, gamma, phi
end

same_series(a, b; atol=1e-3) = length(a) == length(b) &&
    all(isequal(x, y) || isapprox(x, y; atol, rtol=0) for (x, y) in zip(a, b))
same_point(a, b; atol=1e-3) = all(abs.(a .- b) .<= atol)

run_variant(s; regulation, t_end=1000.0) = sim(s; regulation, t_end, start_from_OA=true)

function income_changes(sol, open_access; atol=1e-7, rtol=1e-6)
    p, p0 = sol.prob.p, open_access.prob.p
    p.N == p0.N || throw(ArgumentError("income changes require the same actor population"))
    current = incomes(steady_state(sol), p)
    baseline = incomes(steady_state(open_access), p0)
    # Sort the original actor identities once, never the two income arrays separately.
    order = sortperm(distdata(p0.w̃))
    delta = current.total .- baseline.total
    tolerance = atol .+ rtol .* max.(abs.(current.total), abs.(baseline.total))
    winners = delta .> tolerance
    losers = delta .< .-tolerance
    unchanged = .!(winners .| losers)
    return (; current, baseline, order, delta, tolerance, winners, losers, unchanged,
        winner_share=mean(winners), loser_share=mean(losers),
        unchanged_share=mean(unchanged), total_change=sum(delta),
        gini_change=current.gini - baseline.gini)
end

function public_revenue(sol)
    return sum(incomes(steady_state(sol), sol.prob.p; t=steady_time(sol)).state_revenue)
end

function policy_rows()
    base_s, thresholds, _ = figure_population()
    tourism_s = scenario(base_s;
        w̃=dist(data=thresholds .* 1.2), opportunities=dist(data=thresholds .* 1.2))
    oa_sol = sim(base_s; regulation=0.0, t_end=1000.0)
    royalty_multiplier = 3.47216785
    royalty_rate = 1 - inv(royalty_multiplier)
    royalty_s = scenario(base_s; policy="Economic Incentives",
        policy_target=:cost, policy_method=:taxation, royalty_rate,
        income_cost_fun=(x, p, t) -> distdata(p.w̃),
        income_state_fun=(x, p, t) -> (1 - inv(1 + p.regulation)) .* x[1:p.N] .* x[p.N+1],
        resource_factor_fun=(x, p, t) -> inv(1 + p.regulation))

    # Literal catchability support: the same physical effort earns the same
    # outside income, while its impact increases and its exit threshold falls.
    gear_factor = 1.5
    gear_s = scenario(base_s; policy="Economic Incentives",
        policy_target=:limit, policy_method=:taxation,
        cost=(x, p, t) -> distdata(p.w̃) ./ (1 + p.regulation))
    oa_state = steady_state(oa_sol)
    gear_sol = sim(gear_s; regulation=gear_factor - 1,
        u0=gear_factor .* oa_state[1:base_s.N], y0=oa_state[base_s.N+1], t_end=1000.0)
    rows = [
        (;
            title="Exclusive use rights",
            note="High-threshold exclusion removes 109/140 actors; low-threshold exclusion removes 50/140. Rᵢ is the use right; S penalizes excess use.",
            variants=[
                (label="High θᵢ exclusion", color=BLUE,
                    sol=run_variant(scenario(base_s; policy="Exclusive Use Rights", selector=:top);
                        regulation=109 / 140)),
                (label="Low θᵢ exclusion", color=LIGHTBLUE,
                    sol=run_variant(scenario(base_s; policy="Exclusive Use Rights", selector=:bottom);
                        regulation=50 / 140)),
            ],
        ),
        (;
            title="Tradable use rights",
            note="An aggregate effort quota creates a use-right price ϕ. Use rights Rᵢ are preallocated e.g. to all actors or only to historical users.",
            variants=[
                (label="Equal effort rights", color=ORANGE,
                    sol=run_variant(scenario(base_s; policy="Tradable Use Rights",
                        policy_target=:effort, market_rate=0.05, historical_use_rights=false);
                        regulation=0.50)),
                (label="Historical effort rights", color=LIGHTORANGE,
                    sol=run_variant(scenario(base_s; policy="Tradable Use Rights",
                        policy_target=:effort, market_rate=0.05, historical_use_rights=true);
                        regulation=0.50)),
            ],
        ),
        (;
            title="Protected areas",
            note="Protected area reduces access but creates a spillover effect. Better ecological status can generate a tourism effect, θᵢᴾᴬ⁺ᵗᵒᵘʳⁱˢᵐ.",
            variants=[
                (label="Protected area only", color=GREEN,
                    sol=run_variant(scenario(base_s; policy="Protected Area", m=0.30);
                        regulation=0.50)),
                (label="Protected area + tourism", color=LIGHTGREEN,
                    sol=run_variant(scenario(tourism_s; policy="Protected Area", m=0.30);
                        regulation=0.50)),
            ],
        ),
        (;
            title="Economic policy outcomes",
            note="ρ is the royalty; g multiplies catchability. Royalty: g=1; gear: ρ=0, g=1.5. Outside earnings are unchanged.",
            variants=[
                (label="Tax / royalty", color=BLUE,
                    sol=run_variant(royalty_s; regulation=royalty_multiplier - 1)),
                (label="Gear subsidy", color=ORANGE,
                    sol=gear_sol),
            ],
        ),
    ]
    return rows, oa_sol
end
