#!/usr/bin/env julia

if !isdefined(Main, :SED)
    include(joinpath(@__DIR__, "..", "SED.jl"))
end

using .SED
using CairoMakie
using Printf
using Statistics

CairoMakie.activate!()

const DARK = RGBf(0.11, 0.13, 0.16)
const MUTED = RGBf(0.43, 0.48, 0.57)
const GRID = RGBAf(0.12, 0.16, 0.20, 0.08)
const GRAY = RGBf(0.67, 0.70, 0.74)
const SHADE = RGBAf(0.0, 0.0, 0.0, 0.055)
const BLUE = RGBf(0.05, 0.39, 0.66)
const LIGHTBLUE = RGBf(0.52, 0.70, 0.90)
const TEAL = RGBf(0.05, 0.55, 0.56)
const ORANGE = RGBf(0.95, 0.43, 0.05)
const LIGHTORANGE = RGBf(1.00, 0.66, 0.32)
const GREEN = RGBf(0.10, 0.58, 0.18)
const LIGHTGREEN = RGBf(0.55, 0.82, 0.50)
const RED = RGBf(0.82, 0.12, 0.13)
const PINK = RGBf(0.98, 0.46, 0.47)

withalpha(c, a) = RGBAf(c.r, c.g, c.b, a)

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
    ax.bottomspinecolor = spine
    ax.leftspinecolor = spine
    ax.topspinecolor = spine
    ax.rightspinecolor = spine
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

function deterministic_values(d, N)
    sample!(d, N; random=false)
    return copy(d.data)
end

function figure_population(; N=120)
    threshold_dist = dist(distribution=LogNormal, min=0.055, max=0.94, random=false)
    impact_dist = dist(distribution=LogNormal, min=0.18, max=2.20, random=false)
    thresholds = deterministic_values(threshold_dist, N)
    raw_impact = reverse(deterministic_values(impact_dist, N))
    impacts = raw_impact ./ sum(raw_impact) .* 1.24
    base_s = scenario(base(N=N);
        α=0.05,
        w̃=dist(data=thresholds),
        ū=dist(data=impacts),
        opportunities=dist(data=thresholds),
        title="Open access")
    sample!(base_s; force=true)
    return base_s, thresholds, impacts
end

steady_index(sol) = max(1, length(sol.t) - 2)
steady_state(sol) = sol.u[steady_index(sol)]
steady_time(sol) = sol.t[steady_index(sol)]

function participation(sol)
    p = sol.prob.p
    x = steady_state(sol)
    t = steady_time(sol)
    lim = p.limit(x, p, t)
    return clamp(mean(clamp.(x[1:p.N] ./ lim, 0.0, 1.0)), 0.0, 1.0)
end

function attractor(sol)
    x = steady_state(sol)
    return clamp(x[sol.prob.p.N+1], 0.0, 1.0), participation(sol)
end

function gamma_at(y, p, x_template; t=0.0)
    x = copy(x_template)
    x[p.N+1] = y
    return sum(p.cost(x, p, t) .< y) / p.N
end

function phi_at(y, p, x_template; t=0.0)
    x = copy(x_template)
    x[p.N+1] = y
    costs = p.cost(x, p, t)
    lim = p.limit(x, p, t)
    eligible = findall(<=(1.0), costs)
    isempty(eligible) && return 0.0

    id = eligible[sortperm(costs[eligible])]
    lim_sorted = lim[id]
    pressure = 1.0 - y
    pressure <= 0.0 && return 0.0
    if pressure >= sum(lim_sorted)
        return length(id) / p.N
    end

    cumulative_impact = cumsum(lim_sorted)
    f = sum(cumulative_impact .< pressure)
    if f == 0
        f = pressure / max(lim_sorted[1], eps())
    elseif f < length(id)
        f = f + (pressure - cumulative_impact[f]) / max(lim_sorted[f+1], eps())
    end
    return clamp(f / p.N, 0.0, length(id) / p.N)
end

function curves_for(sol; n=220)
    p = sol.prob.p
    x = steady_state(sol)
    t = steady_time(sol)
    y = collect(range(0.0, 1.0, length=n))
    Γ = [gamma_at(yy, p, x; t) for yy in y]
    Φ = [phi_at(yy, p, x; t) for yy in y]
    return y, Γ, Φ
end

same_series(a, b; atol=1e-3) = length(a) == length(b) && maximum(abs.(a .- b)) <= atol
same_point(a, b; atol=1e-3) = all(abs.(a .- b) .<= atol)

function run_variant(s; regulation, t_end=1000.0)
    return sim(s; regulation, t_end)
end

function figure4_variants()
    base_s, thresholds, impacts = figure_population()
    oa_sol = sim(base_s; regulation=0.0, t_end=1000.0)

    better_gear = scenario(base_s;
        ū=dist(data=impacts .* 1.34),
        title="Better gear")
    sample!(better_gear; force=true)

    threshold_rank = (thresholds .- minimum(thresholds)) ./ (maximum(thresholds) - minimum(thresholds))
    q_access = 0.78 .+ 1.95 ./ (1 .+ exp.(-9.5 .* (threshold_rank .- 0.55)))
    efficiency_shift = scenario(base_s;
        w̃=dist(data=clamp.(thresholds ./ q_access, 0.015, 1.15)),
        opportunities=dist(data=thresholds),
        title="AIO-linked efficiency")
    sample!(efficiency_shift; force=true)

    return [
        (;
            tag="A",
            title="Changing incentives",
            note="Taxes lift thresholds;\nAIO-linked efficiency reshapes w̃ = w/q.",
            variants=[
                (label="Threshold tax", color=RED,
                    sol=run_variant(scenario(base_s; policy="Economic Incentives",
                        policy_target=:cost, policy_method=:taxation, title="Threshold tax");
                        regulation=0.24)),
                (label="AIO-linked efficiency", color=PINK,
                    sol=run_variant(efficiency_shift; regulation=0.0)),
            ],
        ),
        (;
            tag="B",
            title="Changing impact and replacement",
            note="Spillover relaxes pressure;\nbetter gear raises impact capacity.",
            variants=[
                (label="Spillover", color=GREEN,
                    sol=run_variant(scenario(base_s; policy="Protected Area", m=0.55, title="Spillover");
                        regulation=0.24)),
                (label="Better gear", color=LIGHTGREEN,
                    sol=run_variant(better_gear; regulation=0.0)),
            ],
        ),
        (;
            tag="C",
            title="Selecting users",
            note="Access rules matter because selected users\nhave different thresholds and impacts.",
            variants=[
                (label="Low-threshold users excluded", color=BLUE,
                    sol=run_variant(scenario(base_s; policy="Exclusive Use Rights",
                        selector=:bottom, title="Low-threshold users excluded");
                        regulation=0.34)),
                (label="High-threshold users excluded", color=LIGHTBLUE,
                    sol=run_variant(scenario(base_s; policy="Exclusive Use Rights",
                        selector=:top, title="High-threshold users excluded");
                        regulation=0.34)),
            ],
        ),
        (;
            tag="D",
            title="Reallocating rents",
            note="An effort-rights market can leave geometry similar\nwhile redistributing income.",
            variants=[
                (label="Equal effort rights", color=ORANGE,
                    sol=run_variant(scenario(base_s; policy="Tradable Use Rights",
                        policy_target=:effort, market_rate=0.05,
                        historical_use_rights=false, title="Equal rights");
                        regulation=0.48)),
                (label="Historical effort rights", color=LIGHTORANGE,
                    sol=run_variant(scenario(base_s; policy="Tradable Use Rights",
                        policy_target=:effort, market_rate=0.05,
                        historical_use_rights=true, title="Historical rights");
                        regulation=0.48)),
            ],
        ),
    ], oa_sol
end

function draw_phase_panel!(ax, variant, oa_sol; note=nothing)
    style_phase_axis!(ax)
    ax.title = variant.label
    ax.titlecolor = variant.color
    ax.titlesize = 14
    ax.titlefont = :bold
    ax.xlabel = "resource level, y"
    ax.ylabel = "Participation (fraction)"

    poly!(ax, Rect2f(0, 0, 0.5, 1); color=SHADE, strokewidth=0)

    y0, Γ0, Φ0 = curves_for(oa_sol)
    lines!(ax, y0, Γ0; color=withalpha(GRAY, 0.82), linewidth=3.2)
    lines!(ax, y0, Φ0; color=withalpha(GRAY, 0.68), linewidth=1.9, linestyle=:dash)
    yo, po = attractor(oa_sol)
    scatter!(ax, [yo], [po]; color=withalpha(GRAY, 0.92), markersize=9,
        strokecolor=:white, strokewidth=0.7)

    y, Γ, Φ = curves_for(variant.sol)
    yp, pp = attractor(variant.sol)
    gamma_matches_open = same_series(Γ, Γ0)
    phi_matches_open = same_series(Φ, Φ0)
    attractor_matches_open = same_point((yp, pp), (yo, po))
    if !(gamma_matches_open && phi_matches_open && attractor_matches_open)
        if !gamma_matches_open
            lines!(ax, y, Γ; color=variant.color, linewidth=3.2)
        end
        if !phi_matches_open
            lines!(ax, y, Φ; color=withalpha(variant.color, 0.78), linewidth=1.8, linestyle=:dash)
        end
        scatter!(ax, [yp], [pp]; color=variant.color, markersize=11,
            marker=:circle, strokecolor=:white, strokewidth=0.8)
    end

    if note !== nothing
        text!(ax, 0.035, 0.95; text=note, color=MUTED, fontsize=12.8,
            align=(:left, :top))
    end
    return ax
end

function draw_income_panel!(ax, sol, label, color; annotate=false)
    style_income_axis!(ax)
    x = steady_state(sol)
    p = sol.prob.p
    inc = incomes(x, p)
    costs_all = p.cost(x, p, steady_time(sol))
    idx = sortperm(costs_all)
    total = inc.total[idx]
    outside_only = inc.wages_0[idx]

    auto_y = nameof(typeof(p.policy)) == :TradableUseRights
    ymin = auto_y ? min(minimum(total), minimum(outside_only)) :
        min(0.0, minimum(total), minimum(outside_only))
    ymax = max(maximum(total), maximum(outside_only), eps())
    ypad = 0.08 * max(ymax - ymin, eps())

    incomes_plot!(ax, sol; order=true, sort_by_incentives=true,
        color=withalpha(color, 0.64), resource_incomes=false,
        show_active=false, state=x, time=steady_time(sol))
    if annotate
        text!(ax, max(3, round(Int, 0.12 * length(outside_only))), outside_only[max(1, round(Int, 0.20 * length(outside_only)))];
            text="outside only", color=:white, fontsize=12.0, font=:bold,
            align=(:left, :bottom))
    end

    metric = @sprintf("%s\nResource rent: %.2f  Total income: %.2f  Gini: %.2f",
        income_label(label), sum(inc.resource), sum(inc.total), inc.gini)
    ax.title = metric
    ax.titlecolor = color
    ax.titlesize = 11.0
    ax.xlabelvisible = true
    ax.xlabel = "actors ordered by exit threshold"
    ax.xlabelsize = 11.0
    ax.xlabelcolor = MUTED
    xlims!(ax, 0.5, p.N + 0.5)
    ylims!(ax, ymin - 1.20 * ypad, ymax + 1.15 * ypad)
    return ax
end

function income_label(label)
    label == "AIO-linked efficiency" && return "AIO efficiency"
    label == "Low-threshold users excluded" && return "Low T excluded"
    label == "High-threshold users excluded" && return "High T excluded"
    label == "Low mobility (0.2), 30% protected" && return "Low mobility, 30% protected"
    label == "High mobility (0.5), 10% protected" && return "High mobility, 10% protected"
    label == "Higher exit costs / tax" && return "Exit-cost tax"
    label == "Higher effort / gear" && return "Gear / effort ↑"
    return label
end

"""
    figure4_policy_transformations(; outdir=joinpath(@__DIR__, "figures"), save_outputs=true)

Create a 4x4 Figure 4 draft. Each policy row shows both phase geometries first,
followed by the two corresponding income distributions.
"""
function figure4_policy_transformations(; outdir=joinpath(@__DIR__, "figures"), save_outputs=true)
    rows, oa_sol = figure4_variants()
    fig = Figure(size=(1660, 1420), backgroundcolor=:white, fontsize=14)

    Label(fig[0, 1:4], "Policies as transformations of attractor geometry";
        fontsize=28, font=:bold, color=DARK, tellwidth=false)
    Label(fig[1, 1], "Scenario 1 phase", fontsize=15.5, font=:bold, color=DARK, tellwidth=false)
    Label(fig[1, 2], "Scenario 2 phase", fontsize=15.5, font=:bold, color=DARK, tellwidth=false)
    Label(fig[1, 3], "Scenario 1 income", fontsize=15.5, font=:bold, color=DARK, tellwidth=false)
    Label(fig[1, 4], "Scenario 2 income", fontsize=15.5, font=:bold, color=DARK, tellwidth=false)

    for (r, row) in enumerate(rows)
        Label(fig[r + 1, 0], row.title; rotation=π / 2, fontsize=17,
            font=:bold, color=DARK, tellheight=false, tellwidth=true)

        phase1 = Axis(fig[r + 1, 1])
        draw_phase_panel!(phase1, row.variants[1], oa_sol; note=row.note)

        phase2 = Axis(fig[r + 1, 2])
        draw_phase_panel!(phase2, row.variants[2], oa_sol)

        income1 = Axis(fig[r + 1, 3])
        draw_income_panel!(income1, row.variants[1].sol, row.variants[1].label,
            row.variants[1].color; annotate=(r == 1))

        income2 = Axis(fig[r + 1, 4])
        draw_income_panel!(income2, row.variants[2].sol, row.variants[2].label,
            row.variants[2].color)
    end

    rowsize!(fig.layout, 0, Auto(0.25))
    rowsize!(fig.layout, 1, Auto(0.18))
    colsize!(fig.layout, 0, Auto(0.16))
    colsize!(fig.layout, 1, Relative(0.27))
    colsize!(fig.layout, 2, Relative(0.27))
    colsize!(fig.layout, 3, Relative(0.23))
    colsize!(fig.layout, 4, Relative(0.23))
    colgap!(fig.layout, 16)
    rowgap!(fig.layout, 16)

    paths = String[]
    if save_outputs
        isdir(outdir) || mkpath(outdir)
        png = joinpath(outdir, "figure4_policy_transformations.png")
        pdf = joinpath(outdir, "figure4_policy_transformations.pdf")
        save(png, fig, px_per_unit=2)
        save(pdf, fig)
        append!(paths, [png, pdf])
    end
    return fig, paths
end

if abspath(PROGRAM_FILE) == @__FILE__
    _, paths = figure4_policy_transformations()
    println("Wrote:")
    foreach(p -> println("  ", p), paths)
end
