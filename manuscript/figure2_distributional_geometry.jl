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
const ORANGE = RGBf(0.88, 0.43, 0.12)
const TEAL = RGBf(0.05, 0.55, 0.56)
const PURPLE = RGBf(0.45, 0.34, 0.78)
const GRAY = RGBf(0.66, 0.70, 0.76)

withalpha(c, a) = RGBAf(c.r, c.g, c.b, a)

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

function synthetic_actor_geometry(; N=150, seed=72)
    rng = MersenneTwister(seed)
    T = sort(clamp.(rand(rng, Beta(2.15, 2.25), N) .* 0.92 .+ 0.04 .+ 0.035 .* randn(rng, N), 0.02, 0.98))
    base_impact = 0.40 .+ 0.80 .* exp.(-1.45 .* T) .+ 0.22 .* rand(rng, N)
    H = base_impact ./ sum(base_impact) .* 1.34
    asset_index = clamp.(0.15 .+ 0.78 .* T .+ 0.12 .* randn(rng, N), 0.0, 1.0)

    group = map(eachindex(T)) do i
        T[i] < quantile(T, 0.38) && H[i] > median(H) ? "Low threshold / high impact" :
        T[i] > quantile(T, 0.66) ? "High outside option" :
        "Intermediate users"
    end

    return (; T, H, asset_index, group)
end

function cumulative_curves(T, H; points=501)
    y = collect(range(0.0, 1.0, length=points))
    W = [sum(T .< yy) / length(T) for yy in y]
    I = [sum(H[T .< yy]) for yy in y]
    renewal = 1 .- y
    idx = findfirst(I .>= renewal)
    if idx === nothing
        ystar = 1.0
    elseif idx == 1
        ystar = y[1]
    else
        y0, y1 = y[idx-1], y[idx]
        f0, f1 = I[idx-1] - renewal[idx-1], I[idx] - renewal[idx]
        ystar = y0 - f0 * (y1 - y0) / max(f1 - f0, eps())
    end
    Wstar = sum(T .< ystar) / length(T)
    Istar = sum(H[T .< ystar])
    return (; y, W, I, renewal, ystar, Wstar, Istar)
end

function step_coordinates(xs, ys)
    xout = Float64[]
    yout = Float64[]
    push!(xout, xs[1])
    push!(yout, ys[1])
    for i in 2:length(xs)
        push!(xout, xs[i])
        push!(yout, ys[i-1])
        push!(xout, xs[i])
        push!(yout, ys[i])
    end
    return xout, yout
end

"""
    figure2_distributional_geometry(; outdir=joinpath(@__DIR__, "figures"), save_outputs=true)

Create a four-panel draft for Figure 2, deriving participation, cumulative
impact, the resource attractor, and income incidence from the same actor-level
exit thresholds `T_i` and impact capacities `H_i`.
"""
function figure2_distributional_geometry(; outdir=joinpath(@__DIR__, "figures"), save_outputs=true)
    actors = synthetic_actor_geometry()
    curves = cumulative_curves(actors.T, actors.H)
    N = length(actors.T)
    active = actors.T .< curves.ystar

    group_colors = Dict(
        "Low threshold / high impact" => ORANGE,
        "Intermediate users" => TEAL,
        "High outside option" => PURPLE,
    )
    colors = [withalpha(group_colors[g], 0.76) for g in actors.group]

    fig = Figure(size=(1280, 900), backgroundcolor=:white, fontsize=16)
    Label(fig[0, 1:2], "From heterogeneous users to a resource attractor";
        fontsize=26, font=:bold, color=DARK, tellwidth=false)
    Label(fig[1, 1:2],
        "Actor-level exit thresholds and impact capacities generate participation, cumulative pressure, equilibrium resource level, and income incidence.";
        fontsize=13.2, color=MUTED, tellwidth=false)

    ax_a = Axis(fig[2, 1],
        title="A  Actors differ in threshold and impact",
        xlabel="Exit threshold, T_i",
        ylabel="Impact capacity, H_i")
    style_axis!(ax_a)
    scatter!(ax_a, actors.T, actors.H; color=colors, markersize=7 .+ 7 .* actors.asset_index,
        strokecolor=:white, strokewidth=0.45)
    vlines!(ax_a, [curves.ystar]; color=(DARK, 0.38), linestyle=:dash, linewidth=1.5)
    text!(ax_a, curves.ystar + 0.02, maximum(actors.H) * 0.92;
        text=@sprintf("y* = %.2f", curves.ystar), color=DARK, fontsize=12)
    text!(ax_a, 0.05, maximum(actors.H) * 0.96;
        text="each point = actor", color=MUTED, fontsize=12)
    legend_y = maximum(actors.H) * 0.96
    for (j, name) in enumerate(["Low threshold / high impact", "Intermediate users", "High outside option"])
        yloc = legend_y - (j - 1) * maximum(actors.H) * 0.075
        scatter!(ax_a, [0.64], [yloc]; color=group_colors[name], markersize=9, strokewidth=0)
        text!(ax_a, 0.665, yloc; text=name, fontsize=10.5, color=DARK, align=(:left, :center))
    end
    xlims!(ax_a, 0, 1)
    ylims!(ax_a, 0, maximum(actors.H) * 1.10)

    ax_b = Axis(fig[2, 2],
        title="B  Ordering users generates W(y) and I(y)",
        xlabel="Resource level, y",
        ylabel="fraction participating / cumulative impact")
    style_axis!(ax_b)
    for i in 1:N
        lines!(ax_b, [actors.T[i], actors.T[i]], [0.0, min(actors.H[i] * 22, 0.18)];
            color=withalpha(colors[i], 0.30), linewidth=1.1)
    end
    lines!(ax_b, curves.y, curves.W; color=BLUE, linewidth=3)
    lines!(ax_b, curves.y, curves.I; color=ORANGE, linewidth=3)
    text!(ax_b, 0.66, 0.90; text="W(y)", color=BLUE, fontsize=13)
    text!(ax_b, 0.72, 1.18; text="I(y)", color=ORANGE, fontsize=13)
    text!(ax_b, 0.06, 0.15; text="threshold rug", color=MUTED, fontsize=11)
    xlims!(ax_b, 0, 1)
    ylims!(ax_b, 0, 1.36)

    ax_c = Axis(fig[3, 1],
        title="C  Attractor where impact balances renewal",
        xlabel="Resource level, y",
        ylabel="pressure / ecological renewal")
    style_axis!(ax_c)
    lines!(ax_c, curves.y, curves.I; color=ORANGE, linewidth=3.4)
    lines!(ax_c, curves.y, curves.renewal; color=BLUE, linewidth=3.4)
    scatter!(ax_c, [curves.ystar], [curves.Istar]; color=DARK, markersize=13, strokecolor=:white, strokewidth=1)
    lines!(ax_c, [curves.ystar, curves.ystar], [0, curves.Istar];
        color=(DARK, 0.38), linestyle=:dash, linewidth=1.4)
    lines!(ax_c, [0, curves.ystar], [curves.Istar, curves.Istar];
        color=(DARK, 0.22), linestyle=:dash, linewidth=1.2)
    text!(ax_c, curves.ystar + 0.03, curves.Istar + 0.08;
        text=@sprintf("I(y*) = 1 - y*\ny* = %.2f", curves.ystar), fontsize=12, color=DARK)
    text!(ax_c, 0.13, 0.91; text="ecological renewal, 1 - y", color=BLUE, fontsize=12)
    text!(ax_c, 0.68, 0.91; text="cumulative willing impact, I(y)", color=ORANGE, fontsize=12, align=(:center, :center))
    xlims!(ax_c, 0, 1)
    ylims!(ax_c, 0, 1.18)

    ax_d = Axis(fig[3, 2],
        title="D  The same ordering gives incidence and income",
        xlabel="Actors ordered by exit threshold",
        ylabel="income, scaled units (×10³)")
    style_axis!(ax_d)
    rank = collect(range(0.0, 1.0, length=N))
    income_scale = 1000.0
    resource_income = active .* (curves.ystar .* actors.H) .* income_scale
    outside_income = .!active .* (actors.T .* actors.H) .* income_scale
    total_income = resource_income .+ outside_income
    boundary = sum(active) / N
    band!(ax_d, rank, zeros(N), resource_income; color=withalpha(BLUE, 0.32))
    band!(ax_d, rank, resource_income, resource_income .+ outside_income; color=withalpha(ORANGE, 0.30))
    lines!(ax_d, rank, total_income; color=DARK, linewidth=2.3)
    vlines!(ax_d, [boundary]; color=(DARK, 0.42), linestyle=:dash, linewidth=1.5)
    text!(ax_d, max(0.02, boundary * 0.24), maximum(total_income) * 0.82;
        text="harvest", color=BLUE, fontsize=13, align=(:center, :center))
    text!(ax_d, min(0.96, boundary + (1 - boundary) * 0.55), maximum(total_income) * 0.82;
        text="exit / outside option", color=ORANGE, fontsize=13, align=(:center, :center))
    text!(ax_d, boundary + 0.025, maximum(total_income) * 0.34;
        text=@sprintf("harvesting: %.0f%%", 100 * curves.Wstar), fontsize=12, color=DARK)
    xlims!(ax_d, 0, 1)
    ylims!(ax_d, 0, maximum(total_income) * 1.18)

    elements = [
        LineElement(color=BLUE, linewidth=3),
        LineElement(color=ORANGE, linewidth=3),
        PolyElement(color=withalpha(BLUE, 0.32)),
        PolyElement(color=withalpha(ORANGE, 0.30)),
    ]
    labels = ["participation W(y) / renewal", "cumulative impact I(y)", "resource income", "outside-option income"]
    Legend(fig[4, 1:2], elements, labels; orientation=:horizontal, framevisible=false,
        tellwidth=false, labelsize=12.5, patchsize=(24, 12))

    rowsize!(fig.layout, 0, Auto(0.30))
    rowsize!(fig.layout, 1, Auto(0.18))
    rowsize!(fig.layout, 2, Relative(0.48))
    rowsize!(fig.layout, 3, Relative(0.48))
    rowsize!(fig.layout, 4, Auto(0.18))
    rowgap!(fig.layout, 16)
    colgap!(fig.layout, 26)

    paths = String[]
    if save_outputs
        isdir(outdir) || mkpath(outdir)
        png = joinpath(outdir, "figure2_distributional_geometry.png")
        pdf = joinpath(outdir, "figure2_distributional_geometry.pdf")
        save(png, fig, px_per_unit=2)
        save(pdf, fig)
        append!(paths, [png, pdf])
    end

    return fig, paths
end

if abspath(PROGRAM_FILE) == @__FILE__
    _, paths = figure2_distributional_geometry()
    println("Wrote:")
    foreach(p -> println("  ", p), paths)
end
