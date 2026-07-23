#!/usr/bin/env julia

using CairoMakie
using Printf
using Random
using Statistics

CairoMakie.activate!()

const DARK = RGBf(0.12, 0.14, 0.17)
const MUTED = RGBf(0.43, 0.48, 0.56)
const LINE = RGBAf(0.12, 0.16, 0.20, 0.18)
const PANEL = RGBf(0.985, 0.988, 0.992)
const PANEL2 = RGBf(0.955, 0.965, 0.975)
const GREEN = RGBf(0.24, 0.58, 0.38)
const BLUE = RGBf(0.19, 0.42, 0.72)
const ORANGE = RGBf(0.92, 0.50, 0.14)
const PURPLE = RGBf(0.47, 0.36, 0.76)
const RED = RGBf(0.78, 0.25, 0.25)
const GRAY = RGBf(0.62, 0.66, 0.72)

withalpha(c, a) = RGBAf(c.r, c.g, c.b, a)

function setup_canvas!(ax)
    hidespines!(ax)
    hidedecorations!(ax; grid=false)
    xlims!(ax, 0, 1)
    ylims!(ax, 0, 1)
    return ax
end

function panel_header!(ax, number, title, subtitle, color)
    poly!(ax, Rect2f(0, 0, 1, 1); color=PANEL, strokecolor=LINE, strokewidth=1.2)
    poly!(ax, Rect2f(0, 0.855, 1, 0.145); color=withalpha(color, 0.13), strokecolor=:transparent)
    poly!(ax, Rect2f(0, 0, 0.018, 1); color=color, strokecolor=:transparent)
    scatter!(ax, [0.075], [0.925]; color=color, markersize=34)
    text!(ax, 0.075, 0.925; text=string(number), align=(:center, :center),
        color=:white, fontsize=15, font=:bold)
    text!(ax, 0.145, 0.94; text=title, align=(:left, :center),
        color=DARK, fontsize=18, font=:bold)
    text!(ax, 0.145, 0.885; text=subtitle, align=(:left, :center),
        color=MUTED, fontsize=10.5)
end

function card!(ax, x, y, w, h; color=GRAY, title="", body="", fill=PANEL2)
    poly!(ax, Rect2f(x, y, w, h); color=fill, strokecolor=withalpha(color, 0.36), strokewidth=1.0)
    poly!(ax, Rect2f(x, y + h - 0.035, w, 0.035); color=withalpha(color, 0.18), strokecolor=:transparent)
    text!(ax, x + 0.025, y + h - 0.017; text=title, align=(:left, :center),
        color=color, fontsize=11.5, font=:bold)
    text!(ax, x + 0.025, y + h - 0.062; text=body, align=(:left, :top),
        color=DARK, fontsize=10.2, lineheight=0.92)
end

function mini_axes!(ax, x0, y0, w, h; xlabel="", ylabel="")
    lines!(ax, [x0, x0 + w], [y0, y0]; color=LINE, linewidth=1.1)
    lines!(ax, [x0, x0], [y0, y0 + h]; color=LINE, linewidth=1.1)
    for t in 0.25:0.25:1.0
        lines!(ax, [x0 + w * t, x0 + w * t], [y0, y0 + h]; color=RGBAf(0, 0, 0, 0.055), linewidth=0.8)
        lines!(ax, [x0, x0 + w], [y0 + h * t, y0 + h * t]; color=RGBAf(0, 0, 0, 0.055), linewidth=0.8)
    end
    !isempty(xlabel) && text!(ax, x0 + w / 2, y0 - 0.045; text=xlabel, align=(:center, :top),
        color=MUTED, fontsize=9.5)
    !isempty(ylabel) && text!(ax, x0 - 0.045, y0 + h / 2; text=ylabel, align=(:center, :center),
        rotation=pi / 2, color=MUTED, fontsize=9.5)
    return (x = z -> x0 + w * z, y = z -> y0 + h * z)
end

function synthetic_framework_data(; N=150, seed=12)
    rng = MersenneTwister(seed)
    rank = collect(range(1 / (N + 1), 1 - 1 / (N + 1), length=N))
    status = clamp.(rank .+ 0.06 .* randn(rng, N), 0.02, 0.98)
    market = clamp.(0.12 .+ 0.82 .* status .+ 0.08 .* sin.(2pi .* rank), 0.02, 1.15)
    gear = clamp.(1.12 .- 0.52 .* status .+ 0.24 .* exp.(-((rank .- 0.18) ./ 0.17) .^ 2) .+
        0.035 .* randn(rng, N), 0.22, 1.45)
    effort = clamp.(0.45 .+ 0.65 .* (1 .- status) .+ 0.08 .* randn(rng, N), 0.12, 1.35)
    exit_threshold = clamp.(0.10 .+ 0.78 .* market ./ (0.48 .+ gear), 0.02, 1.25)
    impact_raw = gear .* effort .* (1.0 .+ 0.65 .* exp.(-((exit_threshold .- 0.25) ./ 0.14) .^ 2))
    impact = impact_raw ./ sum(impact_raw) .* 1.18
    group = map(status) do s
        s < 0.34 ? "resource dependent" : s < 0.68 ? "mixed options" : "outside options"
    end
    return (; rank, status, market, gear, effort, exit_threshold, impact, group)
end

function phase_curves(c, h; points=401)
    y = collect(range(0, 1, length=points))
    exit_curve = [sum(c .< yy) / length(c) for yy in y]
    order = sortperm(c)
    h_ordered = h[order]
    active_impact = Float64[]
    for yy in y
        pressure = max(0, 1 - yy)
        if pressure <= 0
            push!(active_impact, 0.0)
            continue
        end
        acc = 0.0
        frac = 1.0
        for (j, value) in enumerate(h_ordered)
            if acc + value >= pressure
                frac = ((j - 1) + (pressure - acc) / max(value, eps())) / length(h_ordered)
                break
            end
            acc += value
        end
        push!(active_impact, clamp(frac, 0, 1))
    end
    diff = exit_curve .- active_impact
    idx = findfirst(diff .>= 0)
    ystar = if idx === nothing
        1.0
    elseif idx == 1
        y[1]
    else
        y0, y1 = y[idx-1], y[idx]
        d0, d1 = diff[idx-1], diff[idx]
        y0 - d0 * (y1 - y0) / max(d1 - d0, eps())
    end
    participation = sum(c .< ystar) / length(c)
    return (; y, exit_curve, active_impact, ystar, participation)
end

function draw_field_data!(ax, data)
    card!(ax, 0.07, 0.67, 0.86, 0.15; color=GREEN, title="Ecological context",
        body="regeneration, carrying capacity,\nstock observations")
    card!(ax, 0.07, 0.48, 0.86, 0.15; color=BLUE, title="Harvest economy",
        body="gear, effort limits, prices,\nmarket access")
    card!(ax, 0.07, 0.29, 0.86, 0.15; color=ORANGE, title="Social conditions",
        body="outside options, obligations,\nskills, mobility, status")

    text!(ax, 0.50, 0.225; text="Each actor keeps their joint profile", align=(:center, :center),
        color=DARK, fontsize=11.5, font=:bold)
    colors = [g == "resource dependent" ? ORANGE : g == "mixed options" ? BLUE : GREEN for g in data.group]
    xs = 0.11 .+ 0.78 .* data.status
    ys = 0.085 .+ 0.10 .* data.gear ./ maximum(data.gear)
    scatter!(ax, xs, ys; color=withalpha.(colors, 0.78), markersize=5.0,
        strokecolor=:white, strokewidth=0.25)
    lines!(ax, [0.10, 0.90], [0.075, 0.075]; color=LINE, linewidth=1)
    text!(ax, 0.10, 0.047; text="resource dependent", align=(:left, :center), color=ORANGE, fontsize=8.8)
    text!(ax, 0.90, 0.047; text="outside options", align=(:right, :center), color=GREEN, fontsize=8.8)
end

function draw_model_parameters!(ax)
    rows = [
        (GREEN, "Resource", "r, K", "how fast the resource renews"),
        (BLUE, "Harvest", "q_i, e_i", "gear and effort constraints"),
        (ORANGE, "Economy", "p, w_i", "prices and outside options"),
        (PURPLE, "Response", "alpha_i", "how quickly effort adjusts"),
    ]
    y0 = 0.68
    for (i, (color, label, symbols, note)) in enumerate(rows)
        y = y0 - (i - 1) * 0.155
        poly!(ax, Rect2f(0.08, y - 0.055, 0.84, 0.105);
            color=RGBf(1, 1, 1), strokecolor=withalpha(color, 0.30), strokewidth=1.0)
        scatter!(ax, [0.15], [y]; color=color, markersize=23)
        text!(ax, 0.15, y; text=string(i), align=(:center, :center), color=:white,
            fontsize=10.5, font=:bold)
        text!(ax, 0.23, y + 0.020; text=label, align=(:left, :center),
            color=color, fontsize=12.5, font=:bold)
        text!(ax, 0.88, y + 0.020; text=symbols, align=(:right, :center),
            color=DARK, fontsize=12.5, font=:bold)
        text!(ax, 0.23, y - 0.022; text=note, align=(:left, :center),
            color=MUTED, fontsize=9.3)
    end
    text!(ax, 0.50, 0.12; text="Standard bioeconomic variables,\nkept heterogeneous where actors differ.",
        align=(:center, :center), color=DARK, fontsize=11.0)
end

function draw_relational_variables!(ax, data)
    card!(ax, 0.07, 0.64, 0.86, 0.17; color=ORANGE, title="Exit incentive",
        body="resource level where harvesting\nstops being worthwhile\nc_i = outside option / potential return")
    card!(ax, 0.07, 0.43, 0.86, 0.17; color=BLUE, title="Active impact",
        body="maximum pressure actor can exert\nrelative to resource renewal\nh_i = extraction capacity / renewal")

    map = mini_axes!(ax, 0.16, 0.11, 0.70, 0.23; xlabel="exit incentive", ylabel="active impact")
    maxh = maximum(data.impact)
    colors = [g == "resource dependent" ? ORANGE : g == "mixed options" ? BLUE : GREEN for g in data.group]
    scatter!(ax, map.x.(clamp.(data.exit_threshold, 0, 1)), map.y.(data.impact ./ maxh);
        color=withalpha.(colors, 0.55), markersize=4.5, strokewidth=0)
    lines!(ax, [map.x(0), map.x(1)], [map.y(0), map.y(1)]; color=RGBAf(0, 0, 0, 0.16), linewidth=1)
    text!(ax, 0.50, 0.365; text="The pairing matters: who has low exits\nand who has high impact?",
        align=(:center, :center), color=MUTED, fontsize=10.2)
end

function draw_distributions!(ax, curves)
    map = mini_axes!(ax, 0.13, 0.27, 0.76, 0.42; xlabel="resource level", ylabel="fraction of actors")
    lines!(ax, map.x.(curves.y), map.y.(curves.exit_curve); color=ORANGE, linewidth=3.2)
    lines!(ax, map.x.(curves.y), map.y.(curves.active_impact); color=BLUE, linewidth=3.2)
    scatter!(ax, [map.x(curves.ystar)], [map.y(curves.participation)];
        color=DARK, markersize=12, strokecolor=:white, strokewidth=0.8)
    lines!(ax, [map.x(curves.ystar), map.x(curves.ystar)], [map.y(0), map.y(curves.participation)];
        color=withalpha(DARK, 0.35), linestyle=:dash, linewidth=1.1)
    text!(ax, 0.18, 0.75; text="Sort actors by exit incentive,\nthen accumulate participation\nand active impact.", align=(:left, :top),
        color=DARK, fontsize=11.2)
    text!(ax, 0.66, 0.63; text="exit curve", color=ORANGE, fontsize=11.5, font=:bold)
    text!(ax, 0.58, 0.36; text="impact-balance curve", color=BLUE, fontsize=11.5, font=:bold)
    text!(ax, 0.50, 0.12; text="This is where heterogeneous data become\none readable phase geometry.",
        align=(:center, :center), color=MUTED, fontsize=10.5)
end

function draw_outcomes!(ax, data, curves)
    map = mini_axes!(ax, 0.13, 0.39, 0.76, 0.32; ylabel="participation")
    lines!(ax, map.x.(curves.y), map.y.(curves.exit_curve); color=ORANGE, linewidth=3.0)
    lines!(ax, map.x.(curves.y), map.y.(curves.active_impact); color=BLUE, linewidth=3.0)
    scatter!(ax, [map.x(curves.ystar)], [map.y(curves.participation)];
        color=RED, markersize=13, strokecolor=:white, strokewidth=0.8)
    text!(ax, map.x(curves.ystar) + 0.02, map.y(curves.participation) + 0.035;
        text=@sprintf("attractor\nresource %.2f", curves.ystar),
        align=(:left, :bottom), color=RED, fontsize=9.8, font=:bold)

    N = length(data.exit_threshold)
    active = data.exit_threshold .< curves.ystar
    resource_income = active .* curves.ystar .* data.impact .* 9000
    outside_income = .!active .* data.exit_threshold .* data.impact .* 9000
    total = resource_income .+ outside_income
    order = sortperm(total)
    vals = total[order] ./ maximum(total)
    xs = collect(range(0.13, 0.89, length=N))
    base = 0.11
    barw = 0.76 / N
    for (j, i) in enumerate(order)
        color = active[i] ? BLUE : ORANGE
        poly!(ax, Rect2f(xs[j], base, max(barw * 0.92, 0.002), 0.22 * vals[j]);
            color=withalpha(color, 0.70), strokecolor=:transparent)
    end
    lines!(ax, [0.13, 0.89], [base, base]; color=LINE, linewidth=1.0)
    text!(ax, 0.13, 0.07; text="lower income", align=(:left, :center), color=MUTED, fontsize=8.8)
    text!(ax, 0.89, 0.07; text="higher income", align=(:right, :center), color=MUTED, fontsize=8.8)
    text!(ax, 0.50, 0.35; text="The same actor ordering gives\nincome and equity outcomes.",
        align=(:center, :center), color=DARK, fontsize=10.8)

    chips = [
        ("resource", @sprintf("%.2f", curves.ystar), BLUE),
        ("active", @sprintf("%.0f%%", 100 * curves.participation), ORANGE),
        ("spread", @sprintf("%.2f", std(total) / mean(total)), PURPLE),
    ]
    for (j, (label, value, color)) in enumerate(chips)
        x = 0.12 + (j - 1) * 0.26
        poly!(ax, Rect2f(x, 0.755, 0.23, 0.068); color=withalpha(color, 0.12),
            strokecolor=withalpha(color, 0.34), strokewidth=1)
        text!(ax, x + 0.016, 0.798; text=label, align=(:left, :center),
            color=MUTED, fontsize=8.2)
        text!(ax, x + 0.214, 0.798; text=value, align=(:right, :center),
            color=color, fontsize=11.5, font=:bold)
    end
end

"""
    figure2_framework_sequence(; outdir=joinpath(@__DIR__, "figures"), save_outputs=true)

Create a clean pedagogical replacement for the original framework pipeline:
empirical observations -> model parameters -> actor-level relational variables
-> conditional cumulative curves -> system and distributional outcomes.
"""
function figure2_framework_sequence(; outdir=joinpath(@__DIR__, "figures"), save_outputs=true)
    data = synthetic_framework_data()
    curves = phase_curves(data.exit_threshold, data.impact)

    fig = Figure(size=(1660, 900), backgroundcolor=:white, fontsize=15,
        figure_padding=(24, 20, 20, 18))
    Label(fig[1, 1:9], " ";
        fontsize=1, tellwidth=false)
    Label(fig[2, 1:9], "From empirical heterogeneity to governance outcomes";
        fontsize=28, font=:bold, color=DARK, tellwidth=false)
    Label(fig[3, 1:9],
        "A five-step workflow: keep actor differences, scale them into comparable relational variables, then read the system attractor and distributional outcomes from two curves.";
        fontsize=14.2, color=MUTED, tellwidth=false)

    axes = Axis[]
    panel_specs = [
        (1, "Field data", "measure local heterogeneity", GREEN),
        (2, "Model parameters", "translate observations", PURPLE),
        (3, "Relational variables", "scale to comparable units", ORANGE),
        (4, "Cumulative curves", "order and accumulate", BLUE),
        (5, "System outcomes", "read attractor and equity", RED),
    ]

    for (j, spec) in enumerate(panel_specs)
        col = 2j - 1
        ax = Axis(fig[4, col])
        setup_canvas!(ax)
        number, title, subtitle, color = spec
        panel_header!(ax, number, title, subtitle, color)
        push!(axes, ax)
        if j < length(panel_specs)
            Label(fig[4, col + 1], "->"; fontsize=25, color=withalpha(DARK, 0.55),
                halign=:center, valign=:center, tellheight=false, tellwidth=false)
        end
    end

    draw_field_data!(axes[1], data)
    draw_model_parameters!(axes[2])
    draw_relational_variables!(axes[3], data)
    draw_distributions!(axes[4], curves)
    draw_outcomes!(axes[5], data, curves)

    Label(fig[5, 1:9],
        "Policy instruments enter by changing model parameters or actor variables; the curves shift, and the outcome panels update.";
        fontsize=14.0, color=DARK, tellwidth=false)

    for c in 1:2:9
        colsize!(fig.layout, c, Relative(0.19))
    end
    for c in 2:2:8
        colsize!(fig.layout, c, Fixed(26))
    end
    rowsize!(fig.layout, 1, Fixed(12))
    rowsize!(fig.layout, 2, Fixed(42))
    rowsize!(fig.layout, 3, Fixed(30))
    rowsize!(fig.layout, 4, Relative(1.0))
    rowsize!(fig.layout, 5, Fixed(38))
    rowgap!(fig.layout, 12)
    colgap!(fig.layout, 8)

    paths = String[]
    if save_outputs
        isdir(outdir) || mkpath(outdir)
        png = joinpath(outdir, "figure2_framework_sequence.png")
        pdf = joinpath(outdir, "figure2_framework_sequence.pdf")
        save(png, fig, px_per_unit=2)
        save(pdf, fig)
        append!(paths, [png, pdf])
    end

    return fig, paths
end

if abspath(PROGRAM_FILE) == @__FILE__
    _, paths = figure2_framework_sequence()
    println("Wrote:")
    foreach(p -> println("  ", p), paths)
end
