#!/usr/bin/env julia

using CairoMakie
using Distributions
using Printf
using Random
using Statistics

CairoMakie.activate!()

const DARK = RGBf(0.12, 0.14, 0.17)
const MUTED = RGBf(0.45, 0.50, 0.58)
const GRID = RGBAf(0.12, 0.16, 0.20, 0.08)
const BLUE = RGBf(0.18, 0.40, 0.70)
const TEAL = RGBf(0.05, 0.55, 0.56)
const ORANGE = RGBf(0.88, 0.43, 0.12)
const PURPLE = RGBf(0.45, 0.34, 0.78)

sigmoid(x) = 1 / (1 + exp(-x))
clamp01(x) = clamp(x, 0.0, 1.0)
withalpha(c, a) = RGBAf(c.r, c.g, c.b, a)

function synthetic_exit_readiness(; N=210, seed=41)
    rng = MersenneTwister(seed)
    outside = sort(rand(rng, Beta(2.0, 2.35), N))
    assets = clamp01.(0.18 .+ 0.70 .* outside .+ 0.18 .* randn(rng, N))
    mobility = rand(rng, N) .< clamp01.(0.30 .+ 0.55 .* outside .+ 0.15 .* assets)
    gendered = rand(rng, N) .< clamp01.(0.52 .- 0.20 .* outside .- 0.12 .* assets)

    context = Vector{String}(undef, N)
    for i in eachindex(context)
        context[i] = gendered[i] || assets[i] < 0.30 ? "Gendered / asset constraints" :
                     mobility[i] ? "High mobility / access" :
                     "Mobility constrained"
    end

    offset = map(context) do c
        c == "High mobility / access" ? 0.45 :
        c == "Mobility constrained" ? -0.20 :
        -0.75
    end
    latent = -2.25 .+ 4.35 .* outside .+ 0.90 .* assets .+ offset .+ 0.34 .* randn(rng, N)
    readiness = clamp01.(sigmoid.(latent))
    threshold = clamp01.(0.08 .+ 0.86 .* readiness .+ 0.06 .* randn(rng, N))

    return (; outside, assets, mobility, gendered, context, readiness, threshold)
end

function smooth_curve(xs, offset)
    sigmoid.(-2.25 .+ 4.35 .* xs .+ 0.90 .* xs .+ offset)
end

function style_axis!(ax)
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
    return ax
end

"""
    figure1_empirical_heterogeneity(; outdir=joinpath(@__DIR__, "figures"), save_outputs=true)

Create an illustrative Figure 1 draft for the caption:
"Empirical heterogeneity and exit readiness." The generated data are synthetic
and intended as a visual placeholder until real survey or case-study data are
available.
"""
function figure1_empirical_heterogeneity(; outdir=joinpath(@__DIR__, "figures"), save_outputs=true)
    data = synthetic_exit_readiness()
    groups = ["High mobility / access", "Mobility constrained", "Gendered / asset constraints"]
    group_colors = Dict(
        "High mobility / access" => TEAL,
        "Mobility constrained" => ORANGE,
        "Gendered / asset constraints" => PURPLE,
    )
    point_colors = [withalpha(group_colors[c], 0.76) for c in data.context]
    point_sizes = 6 .+ 7 .* data.assets

    fig = Figure(size=(1300, 870), backgroundcolor=:white, fontsize=17)
    Label(fig[0, 1:3], "Empirical heterogeneity and exit readiness";
        fontsize=26, font=:bold, color=DARK, tellwidth=false)
    Label(fig[1, 1:3],
        "Illustrative survey-style data: exit readiness is observable, heterogeneous, and socially structured.";
        fontsize=13.5, color=MUTED, tellwidth=false)

    ax_a = Axis(fig[2, 1:2],
        title="A  Exit readiness varies among resource users",
        xlabel="Alternative income opportunity (scaled)",
        ylabel="Probability / readiness to exit")
    style_axis!(ax_a)
    scatter!(ax_a, data.outside, data.readiness;
        color=point_colors, markersize=point_sizes, strokecolor=:white, strokewidth=0.55)

    xs = collect(range(0.0, 1.0, length=150))
    line_specs = [
        ("High mobility / access", 0.45),
        ("Mobility constrained", -0.20),
        ("Gendered / asset constraints", -0.75),
    ]
    for (label, offset) in line_specs
        lines!(ax_a, xs, smooth_curve(xs, offset); color=group_colors[label], linewidth=3)
    end
    text!(ax_a, 0.05, 0.93; text="Each point = resource user", fontsize=13, color=MUTED)
    text!(ax_a, 0.67, 0.18; text="same outside option,\ndifferent constraints", fontsize=13, color=MUTED, align=(:left, :center))
    arrows2d!(ax_a, [Point2f(0.64, 0.24)], [Vec2f(-0.08, 0.18)];
        color=(MUTED, 0.75), shaftwidth=2, tipwidth=10, tiplength=12)
    xlims!(ax_a, 0, 1)
    ylims!(ax_a, 0, 1)

    legend_elements = [MarkerElement(marker=:circle, color=group_colors[g], markersize=13) for g in groups]
    Legend(fig[2, 3], legend_elements, groups, "Constraint context";
        framevisible=false, labelsize=13, titlesize=14, tellheight=false, valign=:top)

    ax_b = Axis(fig[3, 1],
        title="B  Exit thresholds are distributed",
        xlabel="Resource-user rank",
        ylabel="Observed exit threshold")
    style_axis!(ax_b)
    order = sortperm(data.threshold)
    rank = collect(range(0.0, 1.0, length=length(order)))
    thresh = data.threshold[order]
    colors_sorted = point_colors[order]
    lines!(ax_b, rank, thresh; color=(MUTED, 0.55), linewidth=2)
    scatter!(ax_b, rank, thresh; color=colors_sorted, markersize=5.2, strokewidth=0)
    band!(ax_b, rank, zeros(length(rank)), thresh; color=RGBAf(0.18, 0.40, 0.70, 0.07))
    text!(ax_b, 0.06, 0.16; text="least ready\nto exit", fontsize=12, color=MUTED)
    text!(ax_b, 0.70, 0.78; text="exit at higher\nresource returns", fontsize=12, color=MUTED)
    xlims!(ax_b, 0, 1)
    ylims!(ax_b, 0, 1)
    ax_b.xticks = ([0, 0.5, 1.0], ["low", "median", "high"])

    ax_c = Axis(fig[3, 2:3],
        title="C  Social variables structure exit readiness",
        xlabel="Standardized association with exit readiness")
    style_axis!(ax_c)
    variables = [
        "Alternative income opportunity",
        "Assets / savings",
        "Mobility",
        "Credit / social networks",
        "Gendered constraints",
    ]
    effects = [0.46, 0.20, 0.24, 0.13, -0.28]
    widths = [0.10, 0.08, 0.07, 0.07, 0.09]
    ys = reverse(collect(1:length(variables)))
    vlines!(ax_c, [0.0]; color=(MUTED, 0.55), linestyle=:dash, linewidth=1.5)
    for i in eachindex(variables)
        col = effects[i] >= 0 ? BLUE : ORANGE
        lines!(ax_c, [effects[i] - widths[i], effects[i] + widths[i]], [ys[i], ys[i]];
            color=col, linewidth=4)
        scatter!(ax_c, [effects[i]], [ys[i]]; color=col, markersize=13, strokecolor=:white, strokewidth=1)
    end
    ax_c.yticks = (ys, variables)
    ax_c.xticks = -0.4:0.2:0.6
    xlims!(ax_c, -0.45, 0.62)
    ylims!(ax_c, 0.4, length(variables) + 0.6)
    text!(ax_c, -0.40, 0.72; text="less ready", color=ORANGE, fontsize=12)
    text!(ax_c, 0.39, 0.72; text="more ready", color=BLUE, fontsize=12)

    Label(fig[4, 1:3],
        "Note: synthetic data are used only to draft the visual form; replace with case-study estimates or survey observations.";
        fontsize=11.5, color=(MUTED, 0.86), tellwidth=false)

    rowsize!(fig.layout, 0, Auto(0.30))
    rowsize!(fig.layout, 1, Auto(0.18))
    rowsize!(fig.layout, 2, Relative(0.56))
    rowsize!(fig.layout, 3, Relative(0.40))
    rowsize!(fig.layout, 4, Auto(0.18))
    colsize!(fig.layout, 3, Relative(0.22))
    rowgap!(fig.layout, 14)
    colgap!(fig.layout, 24)

    paths = String[]
    if save_outputs
        isdir(outdir) || mkpath(outdir)
        png = joinpath(outdir, "figure1_empirical_heterogeneity.png")
        pdf = joinpath(outdir, "figure1_empirical_heterogeneity.pdf")
        save(png, fig, px_per_unit=2)
        save(pdf, fig)
        append!(paths, [png, pdf])
    end

    return fig, paths
end

if abspath(PROGRAM_FILE) == @__FILE__
    _, paths = figure1_empirical_heterogeneity()
    println("Wrote:")
    foreach(p -> println("  ", p), paths)
end
