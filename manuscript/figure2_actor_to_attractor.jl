#!/usr/bin/env julia

using CairoMakie
using Printf
using Random
using SED
using Statistics

CairoMakie.activate!()

const S = SED

const DARK = RGBf(0.10, 0.12, 0.16)
const MUTED = RGBf(0.40, 0.44, 0.52)
const GRID = RGBAf(0.10, 0.14, 0.18, 0.08)
const LINE = RGBAf(0.10, 0.14, 0.18, 0.22)
const ORANGE = RGBf(0.92, 0.48, 0.06)
const BLUE = RGBf(0.18, 0.42, 0.72)
const LIGHTBLUE = RGBf(0.57, 0.68, 0.80)
const GRAY = RGBf(0.70, 0.72, 0.74)
const RED = RGBf(0.76, 0.20, 0.18)

withalpha(c, a) = RGBAf(c.r, c.g, c.b, a)

function style_axis!(ax)
    ax.xgridcolor = GRID
    ax.ygridcolor = GRID
    ax.xticklabelcolor = MUTED
    ax.yticklabelcolor = MUTED
    ax.xlabelcolor = DARK
    ax.ylabelcolor = DARK
    ax.titlecolor = DARK
    ax.subtitlecolor = MUTED
    ax.spinewidth = 0.9
    ax.bottomspinecolor = LINE
    ax.leftspinecolor = LINE
    ax.topspinevisible = false
    ax.rightspinevisible = false
    return ax
end

function package_example(; N=120, impact_relation::Symbol=:negative)
    aio_median = 0.10
    aio_sigma = 0.25
    q_low, q_high, q_fun, relation_label = if impact_relation == :negative
        (0.42, 1.20,
            "1.20 - (1.20 - 0.42) * independent",
            "q decreases with AIO rank")
    elseif impact_relation == :positive
        (0.42, 1.00,
            "0.42 + (1.00 - 0.42) * independent",
            "near switch: q rises ~ proportionally with AIO")
    else
        error("impact_relation must be :negative or :positive")
    end

    s = S.scenario(S.base(N=N);
        aio=S.dist(median=aio_median, sigma=aio_sigma, distribution=S.LogNormal),
        q=S.dist(dependency_fun=q_fun),
        ebar=S.dist(dependency_fun="1.0 + 0 * independent"),
        w̃=S.dist(dependency_fun="aio / q"),
        ū=S.dist(dependency_fun="ebar * q", normalize=true),
        α=fill(0.05, N),
    )
    sol = S.sim(s, t_end=1000)
    end_ix = length(sol.u) > 2 ? length(sol.u) - 2 : length(sol.u)
    p = sol.prob.p
    x = Array(sol.u[end_ix])
    t = sol.t[end_ix]
    cost = p.cost(x, p, t)
    limit = p.limit(x, p, t)
    inc = S.incomes(x, p)
    y = collect(range(0.0, 1.0, length=801))
    exit_curve = [S.Γ(yy, p; t=t) for yy in y]
    active_impact = [S.Φ(yy, p; t=t) for yy in y]
    ystar = x[p.N+1]
    participation = sum(x[1:p.N] ./ limit) / p.N
    active = cost .< ystar
    order = sortperm(cost)
    rho = cor(cost, limit)
    elasticity = cor(log.(p.aio.data), log.(p.q.data)) *
                 std(log.(p.q.data)) / std(log.(p.aio.data))
    gamma_slope = maximum((exit_curve[i+16] - exit_curve[i]) / (y[i+16] - y[i])
        for i in 1:(length(y)-16))
    return (; s, sol, p, x, t, cost, limit, inc, y, exit_curve, active_impact,
        ystar, participation, active, order, impact_relation, rho, elasticity,
        gamma_slope, relation_label, aio_median, aio_sigma, q_low, q_high)
end

function draw_sorted_users!(ax, ex; letter="A", title="Users sorted by exit threshold",
        scenario_label="", h_ylim=nothing)
    order = ex.order
    c = ex.cost[order]
    h = ex.limit[order]
    active = ex.active[order]
    N = length(c)
    x = collect(1:N)
    boundary = sum(active) + 0.5

    for i in x
        color = active[i] ? ORANGE : GRAY
        lines!(ax, [i, i], [0, h[i]]; color=withalpha(color, active[i] ? 0.88 : 0.56), linewidth=1.8)
    end
    scatter!(ax, x[active], h[active]; color=ORANGE, markersize=7.2, strokecolor=:white, strokewidth=0.5)
    scatter!(ax, x[.!active], h[.!active]; color=GRAY, markersize=6.5, strokecolor=:white, strokewidth=0.45)

    vlines!(ax, [boundary]; color=(DARK, 0.72), linestyle=:dash, linewidth=1.5)
    ymax = isnothing(h_ylim) ? maximum(h) * 1.22 : h_ylim

    text!(ax, boundary + 1.0, ymax * 0.90;
        text=@sprintf("y* = %.2f", ex.ystar),
        align=(:left, :bottom), color=DARK, fontsize=12.5)

    text!(ax, boundary * 0.47, ymax * 0.82;
        text="active harvesters\n(cᵢ < y*)", align=(:center, :top),
        color=ORANGE, fontsize=12.5, font=:bold)
    text!(ax, boundary + (N - boundary) * 0.55, ymax * 0.82;
        text="exited users\n(cᵢ > y*)", align=(:center, :top),
        color=MUTED, fontsize=12.5, font=:bold)

    ax.title = "$letter. $title"
    ax.subtitle = scenario_label
    ax.xlabel = "exit threshold cᵢ in non-dimensionalized resource-density units  (low → high)"
    ax.ylabel = "impact capacity hᵢ"
    ax.xticks = ([1, boundary, N], ["low cᵢ", "y*", "high cᵢ"])
    xlims!(ax, 0, N + 2)
    ylims!(ax, 0, ymax)
    style_axis!(ax)
end

function draw_attractor!(ax, ex; letter="B", title="Attractor geometry")
    lines!(ax, ex.y, ex.active_impact; color=BLUE, linewidth=3.2)
    lines!(ax, ex.y, ex.exit_curve; color=ORANGE, linewidth=3.6)
    scatter!(ax, [ex.ystar], [ex.participation];
        color=DARK, markersize=13, strokecolor=:white, strokewidth=1.2)
    vlines!(ax, [ex.ystar]; color=(DARK, 0.68), linestyle=:dash, linewidth=1.4)
    hlines!(ax, [ex.participation]; color=(DARK, 0.48), linestyle=:dash, linewidth=1.2)

    text!(ax, 0.16, 0.72; text="participating\nactive impact",
        color=BLUE, fontsize=12.8, font=:bold)
    text!(ax, 0.72, 0.72;
        text="exit-threshold\nparticipation", color=ORANGE, fontsize=12.8,
        align=(:center, :center), font=:bold)
    text!(ax, ex.ystar + 0.035, ex.participation + 0.035;
        text=@sprintf("attractor\ny* = %.2f", ex.ystar),
        align=(:left, :bottom), color=DARK, fontsize=11.8)
    if ex.gamma_slope > 20
        text!(ax, ex.ystar + 0.045, 0.90;
            text="threshold pile-up:\nsmall y-shift flips many actors",
            align=(:left, :top), color=ORANGE, fontsize=10.8, font=:bold)
    end

    arrows2d!(ax, [Point2f(0.28, 0.15)], [Vec2f(-0.14, 0.0)];
        color=BLUE, shaftwidth=2.2, tipwidth=11, tiplength=13)
    text!(ax, 0.11, 0.19; text="resource\nrecovers", color=BLUE,
        fontsize=11.5, align=(:left, :bottom))
    arrows2d!(ax, [Point2f(0.78, 0.15)], [Vec2f(0.14, 0.0)];
        color=ORANGE, shaftwidth=2.2, tipwidth=11, tiplength=13)
    text!(ax, 0.72, 0.19; text="resource\ndeclines", color=ORANGE,
        fontsize=11.5, align=(:left, :bottom))

    ax.title = "$letter. $title"
    ax.subtitle = ""
    ax.xlabel = "resource density y = X/K"
    ax.ylabel = "fraction of actors"
    ax.xticks = 0:0.25:1
    ax.yticks = 0:0.25:1
    xlims!(ax, 0, 1.02)
    ylims!(ax, 0, 1.02)
    style_axis!(ax)
end

function draw_income_incidence!(ax, ex; letter="C", title="Income incidence",
        income_ylim=nothing, show_legend=true, sort_by::Symbol=:income)
    total_unsorted = ex.inc.total
    order = if sort_by == :income
        sortperm(total_unsorted)
    elseif sort_by == :threshold
        ex.order
    else
        error("sort_by must be :income or :threshold")
    end
    active = ex.active[order]
    N = length(order)
    x = collect(1:N)

    # All income components come from SED.incomes in package_example().
    resource_income = ex.inc.resource[order]
    alt_income = (ex.inc.wages .+ ex.inc.extra)[order]
    total_income = ex.inc.total[order]
    ymax = isnothing(income_ylim) ? maximum(total_income) * 1.24 : income_ylim

    barplot!(ax, x, resource_income; color=withalpha(ORANGE, 0.88), width=0.78)
    barplot!(ax, x, alt_income; offset=resource_income,
        color=withalpha(LIGHTBLUE, 0.92), width=0.78)
    lines!(ax, x, total_income; color=withalpha(DARK, 0.52), linewidth=1.6)

    if sort_by == :income
        inactive_pos = findall(.!active)
        active_pos = findall(active)
        if !isempty(inactive_pos)
            text!(ax, median(inactive_pos), ymax * 0.82;
                text="exited / alternative only", align=(:center, :top),
                color=MUTED, fontsize=12.0, font=:bold)
        end
        if !isempty(active_pos)
            text!(ax, median(active_pos), ymax * 0.66;
                text="active / resource income", align=(:center, :top),
                color=ORANGE, fontsize=12.0, font=:bold)
        end
        scatter!(ax, x, fill(0.012 * ymax, N);
            color=ifelse.(active, ORANGE, LIGHTBLUE), markersize=3.4)
    else
        boundary = sum(active) + 0.5
        vlines!(ax, [boundary]; color=(DARK, 0.72), linestyle=:dash, linewidth=1.5)
        text!(ax, boundary * 0.47, ymax * 0.82;
            text="extractors\n(cᵢ < y*)", align=(:center, :top),
            color=ORANGE, fontsize=12.5, font=:bold)
        text!(ax, boundary + (N - boundary) * 0.55, ymax * 0.82;
            text="exited users\n(cᵢ > y*)", align=(:center, :top),
            color=MUTED, fontsize=12.5, font=:bold)
        text!(ax, boundary + 0.8, ymax * 0.90;
            text="y*", color=DARK, fontsize=12.5, font=:bold)
    end

    if show_legend
        elements = [
            PolyElement(color=withalpha(ORANGE, 0.88)),
            PolyElement(color=withalpha(LIGHTBLUE, 0.92)),
            LineElement(color=withalpha(DARK, 0.52), linewidth=1.8),
        ]
        axislegend(ax, elements,
            ["resource income", "alternative income", "total income"],
            position=:rt, framevisible=false, labelsize=11.5, patchsize=(17, 11), rowgap=0)
    end

    ax.title = "$letter. $title"
    ax.subtitle = ""
    ax.xlabel = sort_by == :income ? "actors sorted by total income" :
        "same users, ordered by exit threshold cᵢ"
    ax.ylabel = "income, scaled units"
    ax.xticks = sort_by == :income ? ([1, N], ["low income", "high income"]) :
        ([1, sum(active) + 0.5, N], ["low cᵢ", "y*", "high cᵢ"])
    xlims!(ax, 0, N + 2)
    ylims!(ax, 0, ymax)
    style_axis!(ax)
end

"""
    figure2_actor_to_attractor(; outdir=joinpath(@__DIR__, "figures"), save_outputs=true, size=(1800, 1420))

Create a clean three-panel pedagogical figure showing how heterogeneous actors
map to a resource attractor and income incidence.
"""
function figure2_actor_to_attractor(; outdir=joinpath(@__DIR__, "figures"), save_outputs=true,
        size=(1800, 1420))
    ex_neg = package_example(impact_relation=:negative)
    ex_pos = package_example(impact_relation=:positive)
    h_ylim = 1.18 * max(maximum(ex_neg.limit), maximum(ex_pos.limit))
    income_ylim = 1.18 * max(maximum(ex_neg.inc.total), maximum(ex_pos.inc.total))

    fig = Figure(size=size, backgroundcolor=:white, fontsize=15,
        figure_padding=(36, 30, 30, 54))

    layout = fig[1, 1] = GridLayout()
    Label(layout[1, 1:3],
        "Lognormal AIO mapped into incentives through ordered efficiency q\nSM criterion: cᵢ = AIOᵢ/qᵢ; a rapid incentive switch occurs near d log q / d log AIO = 1.";
        color=DARK, fontsize=25, font=:bold, lineheight=0.96, tellwidth=false)

    ax_a = Axis(layout[2, 1])
    ax_b = Axis(layout[2, 2])
    ax_c = Axis(layout[2, 3])
    ax_d = Axis(layout[3, 1])
    ax_e = Axis(layout[3, 2])
    ax_f = Axis(layout[3, 3])

    draw_sorted_users!(ax_a, ex_neg; letter="A",
        scenario_label=@sprintf("%s; corr(cᵢ,hᵢ)=%.2f; elasticity=%.2f",
            ex_neg.relation_label, ex_neg.rho, ex_neg.elasticity),
        h_ylim=h_ylim)
    draw_attractor!(ax_b, ex_neg; letter="B")
    draw_income_incidence!(ax_c, ex_neg; letter="C", income_ylim=income_ylim, show_legend=true)

    draw_sorted_users!(ax_d, ex_pos; letter="D",
        scenario_label=@sprintf("%s; corr(cᵢ,hᵢ)=%.2f; elasticity=%.2f",
            ex_pos.relation_label, ex_pos.rho, ex_pos.elasticity),
        h_ylim=h_ylim)
    draw_attractor!(ax_e, ex_pos; letter="E")
    draw_income_incidence!(ax_f, ex_pos; letter="F", income_ylim=income_ylim, show_legend=false)

    rowsize!(layout, 2, Relative(0.5))
    rowsize!(layout, 3, Relative(0.5))
    colsize!(layout, 1, Relative(1 / 3))
    colsize!(layout, 2, Relative(1 / 3))
    colsize!(layout, 3, Relative(1 / 3))
    colgap!(layout, 44)
    rowgap!(layout, 34)

    paths = String[]
    if save_outputs
        isdir(outdir) || mkpath(outdir)
        png = joinpath(outdir, "figure2_actor_to_attractor.png")
        pdf = joinpath(outdir, "figure2_actor_to_attractor.pdf")
        save(png, fig, px_per_unit=1)
        save(pdf, fig)
        append!(paths, [png, pdf])
    end

    return fig, paths
end

if abspath(PROGRAM_FILE) == @__FILE__
    _, paths = figure2_actor_to_attractor()
    println("Wrote:")
    foreach(p -> println("  ", p), paths)
end
