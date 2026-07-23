#!/usr/bin/env julia

include(joinpath(@__DIR__, "figure4_policy_transformations.jl"))

using CairoMakie
using Printf

function style_compact_phase!(ax)
    style_phase_axis!(ax)
    ax.xlabel = "resource level, y"
    ax.ylabel = "Participation (share of all actors)"
    ax.xlabelsize = 12
    ax.ylabelsize = 12
    ax.xticklabelsize = 10
    ax.yticklabelsize = 10
    ax.xticks = 0:0.5:1
    ax.yticks = 0:0.5:1
    return ax
end

function draw_compact_phase!(ax, row, oa_sol)
    style_compact_phase!(ax)
    poly!(ax, Rect2f(0, 0, 0.5, 1); color=SHADE, strokewidth=0)

    y0, Γ0, Φ0 = curves_for(oa_sol)
    yo, po = attractor(oa_sol)
    lines!(ax, y0, Γ0; color=withalpha(GRAY, 0.62), linewidth=3.0)
    lines!(ax, y0, Φ0; color=withalpha(GRAY, 0.46), linewidth=2.1)
    scatter!(ax, [yo], [po]; color=withalpha(GRAY, 0.95), markersize=9,
        strokecolor=:white, strokewidth=0.8)

    used_geometry = Tuple{Vector{Float64},Vector{Float64}}[]
    for (j, v) in enumerate(row.variants)
        y, Γ, Φ = curves_for(v.sol)
        yp, pp = attractor(v.sol)
        already = any(g -> same_series(Γ, g[1]; atol=2e-3) && same_series(Φ, g[2]; atol=2e-3), used_geometry)
        alpha = j == 1 ? 0.98 : 0.62
        lw = j == 1 ? 3.3 : 2.8
        if !already
            !same_series(Γ, Γ0; atol=2e-3) && lines!(ax, y, Γ; color=withalpha(v.color, alpha), linewidth=lw)
            !same_series(Φ, Φ0; atol=2e-3) && lines!(ax, y, Φ; color=withalpha(v.color, alpha), linewidth=2.1)
            push!(used_geometry, (Γ, Φ))
        end
        scatter!(ax, [yp], [pp]; color=withalpha(v.color, alpha), markersize=10,
            strokecolor=:white, strokewidth=0.8)
        label = replace(income_label(v.label), " users" => "", "Threshold " => "")
        text!(ax, clamp(yp + 0.035, 0.04, 0.92), clamp(pp + 0.035 - 0.07 * (j - 1), 0.08, 0.92);
            text=label, color=withalpha(v.color, alpha), fontsize=11.5,
            font=:bold, align=(:left, :center))
    end

    text!(ax, 0.035, 0.95; text=row.title, color=DARK, fontsize=16.5,
        font=:bold, align=(:left, :top))
    text!(ax, 0.035, 0.855; text=replace(row.note, "\n" => " "),
        color=withalpha(MUTED, 0.92), fontsize=10.5, align=(:left, :top))
    return ax
end

function draw_income_pair!(layout, row; annotate=false)
    for (i, v) in enumerate(row.variants)
        ax = Axis(layout[i, 1])
        draw_income_panel!(ax, v.sol, v.label, v.color; annotate=annotate && i == 1)
        ax.titlesize = 12.5
    end
    rowgap!(layout, 2)
end

"""
    figure4_right_columns_compact(; outdir=joinpath(@__DIR__, "figures"), save_outputs=true)

Recreate the phase-diagram and income-distribution columns for the upper four
policy rows of the original Figure 4, using the SED Julia package simulations.
"""
function figure4_right_columns_compact(; outdir=joinpath(@__DIR__, "figures"), save_outputs=true)
    rows, oa_sol = figure4_variants()
    fig = Figure(size=(980, 1340), backgroundcolor=:white, fontsize=13)

    Label(fig[0, 1:2], "Policy transformations in attractor geometry";
        fontsize=24, font=:bold, color=DARK, tellwidth=false)
    Label(fig[1, 1], "Phase diagram", fontsize=15.5, font=:bold, color=DARK, tellwidth=false)
    Label(fig[1, 2], "Income distributions", fontsize=15.5, font=:bold, color=DARK, tellwidth=false)

    for (r, row) in enumerate(rows)
        ax = Axis(fig[r + 1, 1])
        draw_compact_phase!(ax, row, oa_sol)

        income_grid = GridLayout(fig[r + 1, 2])
        draw_income_pair!(income_grid, row; annotate=r == 1)
    end

    rowsize!(fig.layout, 0, Auto(0.30))
    rowsize!(fig.layout, 1, Auto(0.18))
    colsize!(fig.layout, 1, Relative(0.55))
    colsize!(fig.layout, 2, Relative(0.45))
    colgap!(fig.layout, 20)
    rowgap!(fig.layout, 12)

    paths = String[]
    if save_outputs
        isdir(outdir) || mkpath(outdir)
        png = joinpath(outdir, "figure4_right_columns_compact.png")
        pdf = joinpath(outdir, "figure4_right_columns_compact.pdf")
        save(png, fig, px_per_unit=2)
        save(pdf, fig)
        append!(paths, [png, pdf])
    end
    return fig, paths
end

if abspath(PROGRAM_FILE) == @__FILE__
    _, paths = figure4_right_columns_compact()
    println("Wrote:")
    foreach(path -> println("  ", path), paths)
end
