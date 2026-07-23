#!/usr/bin/env julia

using CairoMakie
using LaTeXStrings
using Printf
using Random
using Statistics

CairoMakie.activate!()

include(joinpath(@__DIR__, "figure_style.jl"))

if !isdefined(Main, :SED)
    include(joinpath(@__DIR__, "..", "SED.jl"))
end
const S = Main.SED

const DARK = RGBf(0.12, 0.14, 0.17)
const MUTED = RGBf(0.43, 0.48, 0.56)
const GRID = RGBAf(0.10, 0.14, 0.18, 0.08)
const LINE = RGBAf(0.10, 0.14, 0.18, 0.20)
const PANEL = RGBf(0.985, 0.988, 0.992)
const PANEL_ALT = RGBf(0.955, 0.965, 0.975)
const ORANGE = RGBf(0.93, 0.50, 0.12)
const BLUE = RGBf(0.20, 0.44, 0.76)
const RED = RGBf(0.88, 0.12, 0.28)
const PINK = RGBf(0.96, 0.62, 0.70)
const GRAY = RGBf(0.70, 0.72, 0.75)
const PURPLE = RGBf(0.48, 0.36, 0.78)
const GREEN = RGBf(0.26, 0.58, 0.39)

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
    ax.spinewidth = 1.0
    ax.bottomspinecolor = LINE
    ax.leftspinecolor = LINE
    ax.topspinevisible = false
    ax.rightspinevisible = false
    return ax
end

function setup_panel_axis!(ax)
    hidespines!(ax)
    hidedecorations!(ax; grid=true)
    ax.xgridvisible = false
    ax.ygridvisible = false
    xlims!(ax, 0, 1)
    ylims!(ax, 0, 1)
    return ax
end

function minihist!(ax, data, x0, y0, w, h; color, bins=18, label="", unit="",
        figstyle=paper_figure_style())
    lo, hi = extrema(data)
    if lo == hi
        lo -= 0.5
        hi += 0.5
    end
    edges = collect(range(lo, hi, length=bins + 1))
    counts = zeros(Int, bins)
    for v in data
        j = clamp(searchsortedlast(edges, v), 1, bins)
        counts[j] += 1
    end
    maxcount = max(maximum(counts), 1)
    barw = w / bins
    for j in 1:bins
        poly!(ax, Rect2f(x0 + (j - 1) * barw, y0, barw * 0.86, h * counts[j] / maxcount);
            color=withalpha(color, 0.72), strokecolor=:transparent)
    end
    lines!(ax, [x0, x0 + w], [y0, y0]; color=LINE, linewidth=1.0)
    text!(ax, x0, y0 + h + 0.014; text=label, align=(:left, :bottom),
        fontsize=pt(figstyle, 14.2), color=color, font=:bold)
    text!(ax, x0 + w, y0 - 0.012; text=unit, align=(:right, :top),
        fontsize=pt(figstyle, 12.0), color=MUTED)
end

function chip!(ax, x, y, label, value; color=MUTED, figstyle=paper_figure_style())
    lines!(ax, [x, x + 0.18], [y, y]; color=withalpha(color, 0.32), linewidth=1.0)
    text!(ax, x, y + 0.024; text=label, align=(:left, :center),
        fontsize=pt(figstyle, 12.0), color=MUTED)
    text!(ax, x + 0.18, y + 0.024; text=value, align=(:right, :center),
        fontsize=pt(figstyle, 14.0), color=color, font=:bold)
end

function card!(ax, x, y, w, h; color, title, figstyle=paper_figure_style())
    text!(ax, x, y + h; text=title, align=(:left, :top),
        color=DARK, fontsize=pt(figstyle, 16.0), font=:bold)
end

function panel_title!(layout, text, figstyle)
    Label(layout[1, 1], text;
        fontsize=pt(figstyle, 21.0), font=:bold, color=DARK,
        tellwidth=false, tellheight=false, halign=:left, valign=:top)
    rowsize!(layout, 1, Fixed(pt(figstyle, 32.0)))
    rowgap!(layout, 7)
end

"""
    intro_example(; N=115, seed=42, relation=:positive)

Build a random-sampled dimensional actor population and then pass the derived
non-dimensional exit thresholds and active impacts through the package model.
"""
function intro_example(; N=115, seed=42, relation=:positive)
    Random.seed!(seed)
    relation in (:positive, :negative) ||
        error("relation must be :positive or :negative")

    price = 1.0
    Kdim = 1.0
    rdim = 1.0

    # Dimensional primitives. The non-dimensional model variables are derived
    # from these SEDist objects through dependency functions in the scenario.
    q_dependency = relation == :negative ?
        "independent * (aio / 0.34)^(-0.45)" :
        "independent * (aio / 0.34)^0.65"

    s = S.scenario(S.base(N=N, random=true);
        price=price,
        Kdim=Kdim,
        rdim=rdim,
        aio=S.dist(median=0.34, sigma=0.52, distribution=S.LogNormal,
            random=true, unit="income time⁻¹"),
        # Catchability is conditionally lognormal: the exponent controls how
        # strongly high outside-income actors also tend to have high qᵢ.
        q=S.dist(median=0.98, sigma=0.06, distribution=S.LogNormal,
            dependency_fun=q_dependency,
            random=true, unit="catch effort⁻¹"),
        effort_cap=S.dist(median=0.0106, sigma=0.18, distribution=S.LogNormal,
            random=true, unit="effort time⁻¹"),
        w̃=S.dist(dependency_fun="aio / (price * q * Kdim)",
            unit="resource density"),
        ū=S.dist(dependency_fun="q * effort_cap / rdim",
            unit="resource pressure"),
        α=fill(0.05, N),
        rpk=price * Kdim * rdim,
    )

    S.sample!(s; force=true, random=true)
    sol = S.sim(s, t_end=1600)
    p = sol.prob.p
    x = Array(sol.u[end])
    t = sol.t[end]
    cost = p.cost(x, p, t)
    limit = p.limit(x, p, t)
    ystar = x[p.N+1]
    active = cost .< ystar
    inc = S.incomes(x, p)
    ys = collect(range(0.0, 1.0, length=801))
    exit_curve = [S.Γ(y, p; x=copy(x), t=t) for y in ys]
    active_impact = [S.Φ(y, p; t=t) for y in ys]
    participation = S.Γ(ystar, p; x=copy(x), t=t)
    order = sortperm(cost)

    return (; s, sol, p, x, t, cost, limit, ystar, active, inc, ys,
        exit_curve, active_impact, participation, order,
        aio=p.aio.data, q=p.q.data, effort_cap=p.effort_cap.data,
        price, Kdim, rdim, relation)
end

function draw_dimensional_pipeline!(ax, ex, figstyle)
    setup_panel_axis!(ax)

    card!(ax, 0.035, 0.105, 0.395, 0.720; color=GREEN, title="Dimensional", figstyle)
    minihist!(ax, ex.aio, 0.070, 0.595, 0.320, 0.075; color=ORANGE,
        label="outside income, wᵢ", figstyle)
    minihist!(ax, ex.q, 0.070, 0.445, 0.320, 0.075; color=BLUE,
        label="catchability, qᵢ", figstyle)
    minihist!(ax, ex.effort_cap, 0.070, 0.295, 0.320, 0.075; color=PURPLE,
        label="effort cap, ēᵢ", figstyle)
    chip!(ax, 0.070, 0.220, "price p", @sprintf("%.1f", ex.price); color=ORANGE, figstyle)
    chip!(ax, 0.070, 0.170, "stock K", @sprintf("%.1f", ex.Kdim); color=GREEN, figstyle)
    chip!(ax, 0.070, 0.120, "renewal r", @sprintf("%.1f", ex.rdim); color=BLUE, figstyle)
    lines!(ax, [0.455, 0.545], [0.575, 0.575]; color=MUTED, linewidth=3.8)
    scatter!(ax, [0.555], [0.575]; marker=:rtriangle, color=MUTED, markersize=18)
    text!(ax, 0.505, 0.608; text="rescale", align=(:center, :bottom),
        fontsize=pt(figstyle, 13.0), color=MUTED, font=:bold)

    card!(ax, 0.585, 0.105, 0.370, 0.720; color=ORANGE, title="Relational", figstyle)
    text!(ax, 0.610, 0.675; text="Exit threshold",
        fontsize=pt(figstyle, 15.2), color=ORANGE, font=:bold, align=(:left, :bottom))
    text!(ax, 0.610, 0.615; text=L"\theta_i = w_i/(p q_i K)",
        fontsize=pt(figstyle, 27.0), color=ORANGE, align=(:left, :center))
    minihist!(ax, ex.cost, 0.610, 0.455, 0.310, 0.095; color=ORANGE,
        label="", figstyle)

    text!(ax, 0.610, 0.350; text="Impact potential",
        fontsize=pt(figstyle, 15.2), color=BLUE, font=:bold, align=(:left, :bottom))
    text!(ax, 0.610, 0.290; text=L"\bar{u}_i = q_i\bar{e}_i/r",
        fontsize=pt(figstyle, 27.0), color=BLUE, align=(:left, :center))
    minihist!(ax, ex.limit, 0.610, 0.135, 0.310, 0.095; color=BLUE,
        label="", figstyle)

    text!(ax, 0.230, 0.075;
        text="These would be context specific\nempirical distributions or constants.",
        align=(:center, :center), fontsize=pt(figstyle, 15.6), color=DARK, lineheight=0.88)
    text!(ax, 0.750, 0.075;
        text="These distributions provide a\ncross-context comparable view\nof the resource use system.",
        align=(:center, :center), fontsize=pt(figstyle, 15.6), color=DARK, lineheight=0.88)
end

function draw_sorted_users!(ax, ex, figstyle; letter="B")
    order = ex.order
    h = ex.limit[order]
    active = ex.active[order]
    N = length(order)
    xs = collect(1:N)
    boundary = sum(active) + 0.5
    ymax = maximum(h) * 1.25

    for j in xs
        color = active[j] ? ORANGE : GRAY
        lines!(ax, [j, j], [0, h[j]]; color=withalpha(color, active[j] ? 0.88 : 0.62), linewidth=1.7)
    end
    scatter!(ax, xs[active], h[active]; color=ORANGE, markersize=6.2,
        strokecolor=:white, strokewidth=0.45)
    scatter!(ax, xs[.!active], h[.!active]; color=GRAY, markersize=5.8,
        strokecolor=:white, strokewidth=0.35)
    vlines!(ax, [boundary]; color=withalpha(DARK, 0.72), linestyle=:dash, linewidth=1.4)

    text!(ax, boundary, ymax * 0.98; text="stock level y*",
        align=(:center, :top), fontsize=pt(figstyle, 14.0), color=DARK)
    text!(ax, 0.50, 0.52;
        text=@sprintf("corr(ūᵢ,θᵢ) = %.2f", cor(ex.limit, ex.cost)),
        space=:relative, align=(:center, :center),
        fontsize=pt(figstyle, 15.2), color=DARK, font=:bold)
    text!(ax, max(5, boundary * 0.44), ymax * 0.84;
        text="active harvesters\n(θᵢ < y*)", align=(:center, :top),
        fontsize=pt(figstyle, 15.8), color=ORANGE, font=:bold)
    text!(ax, min(N - 4, boundary + (N - boundary) * 0.58), ymax * 0.84;
        text="exited /\nnon-harvesting\n(θᵢ > y*)", align=(:center, :top),
        fontsize=pt(figstyle, 15.0), color=MUTED, font=:bold)

    ax.xlabel = "Exit thresholds (θ)"
    ax.ylabel = "impact (ū)"
    ax.xticks = ([1, boundary, N], ["low θᵢ", "y*", "high θᵢ"])
    xlims!(ax, 0, N + 2)
    ylims!(ax, 0, ymax)
    style_axis!(ax)
    ax.xlabelsize = pt(figstyle, 15.8)
    ax.ylabelsize = pt(figstyle, 15.8)
    ax.xticklabelsize = pt(figstyle, 12.2)
    ax.yticklabelsize = pt(figstyle, 12.2)
end

function draw_phase!(ax, ex, figstyle)
    lines!(ax, ex.ys, ex.active_impact; color=BLUE, linewidth=2.6, linestyle=:dash)
    lines!(ax, ex.ys, ex.exit_curve; color=ORANGE, linewidth=3.2)
    scatter!(ax, [ex.ystar], [ex.participation]; color=DARK, markersize=17,
        strokecolor=:white, strokewidth=1.25)
    vlines!(ax, [ex.ystar]; color=withalpha(DARK, 0.50), linestyle=:dash, linewidth=1.1)
    hlines!(ax, [ex.participation]; color=withalpha(DARK, 0.35), linestyle=:dash, linewidth=1.0)

    left_start = Point2f(0.03, ex.participation)
    left_stop_x = max(0.07, ex.ystar - 0.060)
    right_start = Point2f(0.97, ex.participation)
    right_stop_x = min(0.93, ex.ystar + 0.060)
    arrows2d!(ax, [left_start],
        [Vec2f(left_stop_x - left_start[1], 0.0)];
        color=DARK, shaftwidth=1.7, tipwidth=10, tiplength=12)
    arrows2d!(ax, [right_start],
        [Vec2f(right_stop_x - right_start[1], 0.0)];
        color=DARK, shaftwidth=1.7, tipwidth=10, tiplength=12)
    label_y = max(0.10, ex.participation - 0.035)
    text!(ax, 0.08, label_y; text="below y*:\nresource recovers",
        fontsize=pt(figstyle, 14.4), color=DARK, align=(:left, :top))
    text!(ax, 0.62, label_y; text="above y*:\nresource declines",
        fontsize=pt(figstyle, 14.4), color=DARK, align=(:left, :top))
    text!(ax, ex.ystar + 0.030, ex.participation - 0.055;
        text=@sprintf("Attractor\ny* = %.2f", ex.ystar),
        fontsize=pt(figstyle, 16.2), color=DARK, align=(:left, :top), font=:bold)
    text!(ax, 0.38, 0.20; text="Sustainable Participation level  I(y)", color=BLUE,
        fontsize=pt(figstyle, 17.0), font=:bold, align=(:left, :top))
    text!(ax, 0.54, 0.94; text="Cumulative participation  P(y)", color=ORANGE,
        fontsize=pt(figstyle, 17.0), font=:bold, align=(:left, :top))

    ax.xlabel = "resource level"
    ax.ylabel = "Participation (share of all actors)"
    ax.xticks = 0:0.25:1
    ax.yticks = 0:0.25:1
    xlims!(ax, 0, 1)
    ylims!(ax, 0, 1.02)
    style_axis!(ax)
    ax.xlabelsize = pt(figstyle, 15.8)
    ax.ylabelsize = pt(figstyle, 15.8)
    ax.xticklabelsize = pt(figstyle, 12.2)
    ax.yticklabelsize = pt(figstyle, 12.2)
end

function income_outcomes_label(ex)
    @sprintf("Resource income = %.2f   Total income = %.2f   Gini = %.2f",
        sum(ex.inc.resource), sum(ex.inc.total), ex.inc.gini)
end

function draw_income_component_legend!(ax, xmin, ymax, yrange, figstyle)
    x0 = xmin + 4.0
    ys = ymax .- [0.13, 0.22, 0.31] .* yrange
    sw = 4.8
    sh = 0.026 * yrange
    entries = [
        (withalpha(RED, 0.86), "color = resource surplus income"),
        (withalpha(PINK, 0.70), "whitened color = opportunity cost"),
        (withalpha(GRAY, 0.72), "gray = alternative incomes"),
    ]
    for (y, (color, label)) in zip(ys, entries)
        poly!(ax, Rect2f(x0, y - sh / 2, sw, sh); color, strokecolor=:transparent)
        text!(ax, x0 + sw + 2.0, y; text=label,
            align=(:left, :center), color=DARK, fontsize=pt(figstyle, 14.3), font=:bold)
    end
end

function draw_income_order_axis!(ax, ex, figstyle; orderby::Symbol, xlabel, show_legend=false)
    sort_by_incentives = orderby == :threshold
    idx = sort_by_incentives ? sortperm(ex.p.cost(ex.x, ex.p, ex.t)) :
        orderby == :total ? sortperm(ex.inc.total) :
        error("orderby must be :threshold or :total")
    N = length(idx)
    xs = collect(1:N)
    total = ex.inc.total[idx]
    outside = ex.inc.wages_0[idx]
    trade = ex.inc.trade[idx]
    resource_surplus_income = total .- outside
    active = ex.active[idx]
    ymax = max(maximum(total), maximum(outside), maximum(trade), eps()) * 1.20
    ymin = min(0.0, minimum(total), minimum(outside), minimum(trade)) * 1.08

    inactive = .!active
    if any(inactive)
        barplot!(ax, xs[inactive], total[inactive];
            color=withalpha(GRAY, 0.72), width=0.78, strokecolor=:transparent)
    end
    if any(active)
        barplot!(ax, xs[active], outside[active];
            color=withalpha(PINK, 0.70), width=0.78, strokecolor=:transparent)
        barplot!(ax, xs[active], resource_surplus_income[active];
            offset=outside[active], color=withalpha(RED, 0.86),
            width=0.78, strokecolor=:transparent)
    end

    ax.xlabel = xlabel
    ax.ylabel = "income"
    ax.xticks = ([1, N], ["low", "high"])
    xlims!(ax, 0, N + 2)
    ylims!(ax, ymin, ymax)
    show_legend && draw_income_component_legend!(ax, 0.0, ymax, ymax - ymin, figstyle)
    style_axis!(ax)
    ax.xlabelsize = pt(figstyle, 16.6)
    ax.xlabelfont = :bold
    ax.ylabelsize = pt(figstyle, 15.0)
    ax.xticklabelsize = pt(figstyle, 12.0)
    ax.yticklabelsize = pt(figstyle, 12.0)
    return ax
end

function draw_income_comparison!(layout, ex, figstyle; letter="D", show_title=true)
    top_row = 1
    if show_title
        Label(layout[1, 1], "$letter. Income distribution at the attractor";
            fontsize=pt(figstyle, 21.0), font=:bold, color=DARK,
            tellwidth=false, halign=:left)
        top_row = 2
    end
    bottom_row = top_row + 1
    ax_top = Axis(layout[top_row, 1])
    ax_bottom = Axis(layout[bottom_row, 1])
    draw_income_order_axis!(ax_top, ex, figstyle; orderby=:threshold,
        xlabel="Same actors ordered by exit threshold θᵢ", show_legend=true)
    draw_income_order_axis!(ax_bottom, ex, figstyle; orderby=:total,
        xlabel="Same actors ordered by total income")
    text!(ax_bottom, 0.025, 0.965; text=income_outcomes_label(ex),
        space=:relative, align=(:left, :top), color=MUTED,
        fontsize=pt(figstyle, 15.4), font=:bold)
    if show_title
        rowsize!(layout, 1, Auto(0.10))
        rowsize!(layout, 2, Relative(0.46))
        rowsize!(layout, 3, Relative(0.44))
    else
        rowsize!(layout, 1, Relative(0.46))
        rowsize!(layout, 2, Relative(0.44))
    end
    rowgap!(layout, 10)
    return layout
end

"""
    figure_intro_dimensional_pipeline(; outdir=joinpath(@__DIR__, "figures"), save_outputs=true)

Create a first-pass introductory figure from dimensional actor distributions
to non-dimensional thresholds/impacts, attractor geometry, and income incidence.
"""
function figure_intro_dimensional_pipeline(; outdir=joinpath(@__DIR__, "figures"),
        save_outputs=true, relation=:positive,
        figstyle=paper_figure_style(size=(1700, 1420), font_scale=1.34, px_per_unit=1))
    ex = intro_example(; relation)

    fig = Figure(size=figsize(figstyle), backgroundcolor=:white, fontsize=pt(figstyle, 16),
        figure_padding=(32, 28, 42, 38))

    panel_a = GridLayout(fig[1, 1])
    panel_b = GridLayout(fig[1, 2])
    panel_c = GridLayout(fig[2, 1])
    panel_d = GridLayout(fig[2, 2])

    panel_title!(panel_a, "A) Dimensional and relational parameter distributions", figstyle)
    panel_title!(panel_b, "B) Correlation between exit threshold and impact", figstyle)
    panel_title!(panel_c, "C) Extraction - resource balance", figstyle)
    panel_title!(panel_d, "D) Income distribution at the attractor", figstyle)

    ax_a = Axis(panel_a[2, 1])
    ax_b = Axis(panel_b[2, 1])
    ax_c = Axis(panel_c[2, 1])
    income_layout = GridLayout(panel_d[2, 1])

    draw_dimensional_pipeline!(ax_a, ex, figstyle)
    draw_sorted_users!(ax_b, ex, figstyle; letter="B")
    draw_phase!(ax_c, ex, figstyle)
    draw_income_comparison!(income_layout, ex, figstyle; letter="D", show_title=false)

    rowsize!(fig.layout, 1, Relative(0.51))
    rowsize!(fig.layout, 2, Relative(0.49))
    colgap!(fig.layout, 42)
    rowgap!(fig.layout, 22)

    paths = String[]
    if save_outputs
        isdir(outdir) || mkpath(outdir)
        suffix = relation == :negative ? "_negative_corr" : ""
        png = joinpath(outdir, "figure_intro_dimensional_pipeline$(suffix).png")
        pdf = joinpath(outdir, "figure_intro_dimensional_pipeline$(suffix).pdf")
        save(png, fig, px_per_unit=px_per_unit(figstyle))
        save(pdf, fig)
        append!(paths, [png, pdf])
    end
    return fig, paths
end

if abspath(PROGRAM_FILE) == @__FILE__
    _, paths = figure_intro_dimensional_pipeline()
    println("Wrote:")
    foreach(p -> println("  ", p), paths)
end
