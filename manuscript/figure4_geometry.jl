#!/usr/bin/env julia

if !isdefined(Main, :SED)
    include(joinpath(@__DIR__, "..", "SED.jl"))
end

using .SED
using CairoMakie
using Printf

CairoMakie.activate!()

const ORANGE = RGBf(0.88, 0.43, 0.12)
const BLUE = RGBf(0.18, 0.40, 0.70)
const GRAY = RGBf(0.58, 0.62, 0.68)
const DARK = RGBf(0.12, 0.14, 0.17)
const PURPLE = RGBf(0.45, 0.34, 0.78)

steady_index(sol) = max(1, length(sol.t) - 2)

function state_at(sol)
    copy(sol.u[steady_index(sol)])
end

function participation_at(sol)
    p = sol.prob.p
    i = steady_index(sol)
    x = sol.u[i]
    lim = p.limit(x, p, sol.t[i])
    return x[p.N+1], sum(clamp.(x[1:p.N] ./ lim, 0.0, 1.0)) / p.N
end

function gamma_at_state(y, p, x_template; t=0.0)
    x = copy(x_template)
    x[p.N+1] = y
    return sum(p.cost(x, p, t) .< y) / p.N
end

function phi_at_state(y, p, x_template; t=0.0)
    x = copy(x_template)
    x[p.N+1] = y
    c = p.cost(x, p, t)
    id = sortperm(c)
    lim = p.limit(x, p, t)
    cumulative_impact = cumsum(lim[id])
    pressure = 1.0 - y
    f = sum(cumulative_impact .< pressure)

    if f == 0
        frac = pressure / lim[id[1]]
    elseif f < p.N
        frac = f + (pressure - cumulative_impact[f]) / lim[id[f+1]]
    else
        frac = p.N
    end
    return clamp(frac / p.N, 0.0, 1.0)
end

function ordered_population(; N=140)
    r = collect(range(1 / (N + 1), 1 - 1 / (N + 1), length=N))
    w = 0.07 .+ 0.86 .* r .^ 1.35
    raw_impact = 0.20 .+ 1.25 .* exp.(-2.0 .* r)
    u = raw_impact ./ sum(raw_impact) .* 1.35
    selector_score = u
    return (; w̃=dist(data=w), ū=dist(data=u), opportunities=dist(data=selector_score))
end

function geometry_scenarios(; N=140)
    pop = ordered_population(; N)
    base_s = scenario(base(N=N); pop..., α=0.05, title="Open access")
    sample!(base_s; force=true)

    mechanisms = [
        (;
            tag="A",
            title="Changing incentive thresholds",
            subtitle="costs/taxes move the incentive curve Γ",
            scenario=scenario(base_s; policy="Economic Incentives", policy_target=:cost, policy_method=:taxation),
            regulation=0.38,
            focus=:gamma,
        ),
        (;
            tag="B",
            title="Changing impact curves",
            subtitle="gear/effort changes move the impact-balance curve Φ",
            scenario=scenario(base_s; policy="Economic Incentives", policy_target=:limit, policy_method=:multiplicative),
            regulation=0.42,
            focus=:phi,
        ),
        (;
            tag="C",
            title="Selecting users",
            subtitle="access rules remove a chosen part of the population",
            scenario=scenario(base_s; policy="Exclusive Use Rights", selector=:top),
            regulation=0.28,
            focus=:selection,
        ),
        (;
            tag="D",
            title="Rent reallocation",
            subtitle="use-right prices shift incentives and redistribute rents",
            scenario=scenario(base_s; policy="Tradable Use Rights", policy_target=:effort, market_rate=0.05, buyer_bias=0.0),
            regulation=0.45,
            focus=:rent,
        ),
    ]

    open_sol = sim(base_s, regulation=0.0, t_end=1000)
    policy_sols = [sim(m.scenario, regulation=m.regulation, t_end=1000) for m in mechanisms]
    return base_s, open_sol, mechanisms, policy_sols
end

function panel!(ax, open_sol, mechanism, sol)
    open_p = open_sol.prob.p
    policy_p = sol.prob.p
    ys = collect(range(0.0, 1.0, length=240))
    open_state = state_at(open_sol)
    policy_state = state_at(sol)

    open_gamma = [gamma_at_state(y, open_p, open_state) for y in ys]
    open_phi = [phi_at_state(y, open_p, open_state) for y in ys]
    policy_gamma = [gamma_at_state(y, policy_p, policy_state) for y in ys]
    policy_phi = [phi_at_state(y, policy_p, policy_state) for y in ys]

    lines!(ax, ys, open_gamma; color=(GRAY, 0.55), linewidth=2.4)
    lines!(ax, ys, open_phi; color=(GRAY, 0.38), linewidth=2.4, linestyle=:dash)
    lines!(ax, ys, policy_gamma; color=ORANGE, linewidth=3.2)
    lines!(ax, ys, policy_phi; color=BLUE, linewidth=3.2)

    yo, po = participation_at(open_sol)
    yp, pp = participation_at(sol)
    scatter!(ax, [yo], [po]; color=GRAY, markersize=10, strokewidth=0)
    scatter!(ax, [yp], [pp]; color=DARK, markersize=12, strokewidth=0)
    lines!(ax, [yp, yp], [0, pp]; color=(DARK, 0.35), linewidth=1.4, linestyle=:dash)

    text!(ax, 0.025, 0.965; text=mechanism.tag, font=:bold, fontsize=20, align=(:left, :top), color=DARK)
    text!(ax, 0.105, 0.955; text=mechanism.title, font=:bold, fontsize=15, align=(:left, :top), color=DARK)
    text!(ax, 0.105, 0.895; text=mechanism.subtitle, fontsize=10.5, align=(:left, :top), color=(DARK, 0.68))

    if mechanism.focus == :gamma
        x0 = 0.50
        gy_open = gamma_at_state(x0, open_p, open_state)
        gy_policy = gamma_at_state(x0, policy_p, policy_state)
        arrows2d!(ax, [Point2f(x0, gy_open)], [Vec2f(0, gy_policy - gy_open)];
            color=ORANGE, shaftwidth=2.0, tipwidth=10, tiplength=12)
        text!(ax, 0.56, max(gy_policy, 0.13); text="Γ shifts", fontsize=10.5, color=ORANGE)
    elseif mechanism.focus == :phi
        x0 = 0.42
        py_open = phi_at_state(x0, open_p, open_state)
        py_policy = phi_at_state(x0, policy_p, policy_state)
        arrows2d!(ax, [Point2f(x0, py_open)], [Vec2f(0, py_policy - py_open)];
            color=BLUE, shaftwidth=2.0, tipwidth=10, tiplength=12)
        text!(ax, 0.47, min(max(py_policy, 0.16), 0.88); text="Φ moves", fontsize=10.5, color=BLUE)
    elseif mechanism.focus == :selection
        n = round(Int, mechanism.regulation * policy_p.N)
        text!(ax, 0.60, 0.16; text=@sprintf("%d%% selected out", round(100 * n / policy_p.N)),
            fontsize=10.5, color=BLUE)
        band_y = 1.0 - n / policy_p.N
        poly!(ax, Rect2f(0.0, band_y, 1.0, 1.0 - band_y); color=(BLUE, 0.08), strokewidth=0)
    elseif mechanism.focus == :rent
        inc = incomes(sol)
        positive = sum(max.(inc.trade, 0.0))
        negative = -sum(min.(inc.trade, 0.0))
        scale = 0.16 / max(positive, negative, eps())
        poly!(ax, Rect2f(0.06, 0.105, positive * scale, 0.025); color=(PURPLE, 0.55), strokewidth=0)
        poly!(ax, Rect2f(0.06, 0.065, negative * scale, 0.025); color=(ORANGE, 0.45), strokewidth=0)
        text!(ax, 0.06, 0.145; text="trade rents", fontsize=10.5, color=PURPLE)
        text!(ax, 0.23, 0.105; text="+", fontsize=10, color=PURPLE, align=(:left, :center))
        text!(ax, 0.23, 0.065; text="-", fontsize=10, color=ORANGE, align=(:left, :center))
    end

    xlims!(ax, 0, 1)
    ylims!(ax, 0, 1)
    ax.xlabel = "resource level, y"
    ax.ylabel = "Participation (fraction)"
    ax.xticks = 0:0.25:1
    ax.yticks = 0:0.25:1
    ax.xgridcolor = RGBAf(0.1, 0.13, 0.16, 0.08)
    ax.ygridcolor = RGBAf(0.1, 0.13, 0.16, 0.08)
    ax.spinewidth = 0.8
    spine_color = RGBAf(0.1, 0.13, 0.16, 0.20)
    ax.bottomspinecolor = spine_color
    ax.leftspinecolor = spine_color
    ax.topspinecolor = spine_color
    ax.rightspinecolor = spine_color
    return ax
end

"""
    figure4_policy_geometry(; outdir=joinpath(@__DIR__, "figures"), save_outputs=true)

Create a four-panel replacement draft for Figure 4. The panels classify policy
implementation by the geometric operation it performs on the phase diagram.
"""
function figure4_policy_geometry(; outdir=joinpath(@__DIR__, "figures"), save_outputs=true)
    _, open_sol, mechanisms, policy_sols = geometry_scenarios()

    fig = Figure(size=(1120, 820), backgroundcolor=:white)
    Label(fig[0, 1:2], "Policy implementation as geometric transformations";
        fontsize=24, font=:bold, color=DARK, tellwidth=false)
    Label(fig[1, 1:2],
        "Each panel uses the same actor population. Gray curves are open access; colored curves show one policy implementation.";
        fontsize=12.5, color=(DARK, 0.68), tellwidth=false)

    axes = [
        Axis(fig[2, 1]),
        Axis(fig[2, 2]),
        Axis(fig[3, 1]),
        Axis(fig[3, 2]),
    ]
    for (ax, mechanism, sol) in zip(axes, mechanisms, policy_sols)
        panel!(ax, open_sol, mechanism, sol)
    end

    elements = [
        LineElement(color=(GRAY, 0.55), linewidth=3),
        LineElement(color=(GRAY, 0.38), linewidth=3, linestyle=:dash),
        LineElement(color=ORANGE, linewidth=4),
        LineElement(color=BLUE, linewidth=4),
        MarkerElement(color=DARK, marker=:circle, markersize=12),
    ]
    labels = ["open Γ", "open Φ", "policy Γ", "policy Φ", "policy attractor"]
    Legend(fig[4, 1:2], elements, labels; orientation=:horizontal, framevisible=false,
        tellwidth=false, tellheight=true, labelsize=11.5, patchsize=(28, 12))

    rowsize!(fig.layout, 0, Auto(0.35))
    rowsize!(fig.layout, 1, Auto(0.22))
    colgap!(fig.layout, 28)
    rowgap!(fig.layout, 18)

    paths = String[]
    if save_outputs
        isdir(outdir) || mkpath(outdir)
        png = joinpath(outdir, "figure4_policy_geometry.png")
        pdf = joinpath(outdir, "figure4_policy_geometry.pdf")
        save(png, fig, px_per_unit=2)
        save(pdf, fig)
        append!(paths, [png, pdf])
    end
    return fig, paths
end

if abspath(PROGRAM_FILE) == @__FILE__
    _, paths = figure4_policy_geometry()
    println("Wrote:")
    foreach(p -> println("  ", p), paths)
end
