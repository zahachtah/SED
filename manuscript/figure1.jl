#!/usr/bin/env julia

using CairoMakie

CairoMakie.activate!()

const FIG1_DARK = RGBf(0.08, 0.08, 0.08)
const FIG1_TEAL = RGBf(69 / 255, 129 / 255, 142 / 255)
const FIG1_GOLD = RGBf(241 / 255, 194 / 255, 50 / 255)
const FIG1_RED = RGBf(204 / 255, 0, 0)
const FIG1_BAR_COLORS = [
    RGBf(217 / 255, 217 / 255, 217 / 255),
    RGBf(61 / 255, 133 / 255, 198 / 255),
    RGBf(111 / 255, 168 / 255, 220 / 255),
    RGBf(159 / 255, 197 / 255, 232 / 255),
    RGBf(249 / 255, 203 / 255, 156 / 255),
    RGBf(234 / 255, 153 / 255, 153 / 255),
]

"""
    figure1(; outdir=joinpath(@__DIR__, "figures"),
        save_outputs=true, raster_scale=4)

Recreate the adapted empirical Figure 1 as vector graphics. The plotted values
are digitized from the version embedded in the manuscript; this script changes
only rendering quality, not the displayed empirical pattern.
"""
function figure1(; outdir=joinpath(@__DIR__, "figures"),
        save_outputs=true, raster_scale=4)
    x = 2.0 .^ range(0.0, 4.0; length=17)
    wealthiest = [
        0.606, 0.639, 0.671, 0.706, 0.734, 0.760, 0.785, 0.810, 0.832,
        0.851, 0.870, 0.886, 0.899, 0.911, 0.924, 0.934, 0.943,
    ]
    moderate = [
        0.400, 0.437, 0.472, 0.506, 0.544, 0.579, 0.614, 0.649, 0.684,
        0.712, 0.741, 0.766, 0.788, 0.813, 0.835, 0.851, 0.870,
    ]
    poorest = [
        0.230, 0.253, 0.282, 0.313, 0.345, 0.380, 0.411, 0.449, 0.484,
        0.522, 0.559, 0.595, 0.627, 0.658, 0.690, 0.718, 0.747,
    ]

    fig = Figure(size=(1145, 471), backgroundcolor=:white, fontsize=17,
        figure_padding=(28, 24, 18, 20))

    ax_left = Axis(fig[1, 1],
        title="Wide between-household variability",
        xlabel="No. household occupations",
        ylabel="Probability of exit",
        xscale=log10,
        xticks=([1, 2, 3, 5, 7, 10, 13, 16],
            ["1", "2", "3", "5", "7", "10", "13", "16"]),
        yticks=0:0.2:1,
        titlesize=21,
        titlefont=:bold,
        xlabelsize=17,
        ylabelsize=17,
        xticklabelsize=15,
        yticklabelsize=15,
        xgridvisible=false,
        ygridvisible=false,
        topspinevisible=false,
        rightspinevisible=false)
    lines!(ax_left, x, wealthiest; color=FIG1_TEAL, linewidth=3.6)
    lines!(ax_left, x, moderate; color=FIG1_GOLD, linewidth=3.6)
    lines!(ax_left, x, poorest; color=FIG1_RED, linewidth=3.6)
    xlims!(ax_left, 0.88, 17.5)
    ylims!(ax_left, 0, 1.05)

    line_elements = [
        LineElement(color=FIG1_TEAL, linewidth=4),
        LineElement(color=FIG1_GOLD, linewidth=4),
        LineElement(color=FIG1_RED, linewidth=4),
    ]
    axislegend(ax_left, line_elements, ["Wealthiest", "Moderate", "Poorest"],
        "Household economic status";
        position=:rb, framevisible=false, labelsize=15, titlesize=15,
        titlefont=:bold, patchsize=(40, 12), rowgap=0)

    categories = ["Other", "Income", "Opportunity", "Lost opportunity",
        "Legislation", "Age or health"]
    entering = [-0.09, -0.26, -0.11, -0.335, -0.09, -0.11]
    leaving = [0.12, 0.19, 0.11, 0.0, 0.18, 0.46]
    ys = reverse(collect(1:length(categories)))

    ax_right = Axis(fig[1, 2],
        title="Multitude of Decision factors",
        xticks=([-0.5, 0.0, 0.5], ["50%", "0", "50%"]),
        yticks=(ys, categories),
        titlesize=21,
        titlefont=:bold,
        xticklabelsize=15,
        yticklabelsize=15,
        xgridvisible=false,
        ygridvisible=false,
        topspinevisible=false,
        rightspinevisible=false,
        leftspinevisible=false,
        yticksize=0,
        yticklabelpad=12)
    vlines!(ax_right, [0.0]; color=:black, linewidth=1.0)
    for (y, left, right, color) in zip(ys, entering, leaving, FIG1_BAR_COLORS)
        left < 0 && poly!(ax_right, Rect2f(left, y - 0.48, -left, 0.96); color)
        right > 0 && poly!(ax_right, Rect2f(0, y - 0.48, right, 0.96); color)
    end
    text!(ax_right, -0.25, 0.22; text="Entering", align=(:center, :center),
        fontsize=16, color=FIG1_DARK)
    text!(ax_right, 0.25, 0.22; text="Leaving", align=(:center, :center),
        fontsize=16, color=FIG1_DARK)
    xlims!(ax_right, -0.5, 0.5)
    ylims!(ax_right, 0.05, 6.65)

    colsize!(fig.layout, 1, Relative(0.57))
    colsize!(fig.layout, 2, Relative(0.43))
    colgap!(fig.layout, 62)

    paths = String[]
    if save_outputs
        mkpath(outdir)
        png = joinpath(outdir, "figure1.png")
        pdf = joinpath(outdir, "figure1.pdf")
        save(png, fig; px_per_unit=raster_scale)
        save(pdf, fig)
        append!(paths, [png, pdf])
    end
    return fig, paths
end

if abspath(PROGRAM_FILE) == @__FILE__
    _, paths = figure1()
    println("Wrote:")
    foreach(path -> println("  ", path), paths)
end
