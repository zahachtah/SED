#!/usr/bin/env julia

using CairoMakie
using Printf
using Statistics

CairoMakie.activate!()

const DARK = RGBf(0.12, 0.14, 0.17)
const MUTED = RGBf(0.45, 0.50, 0.58)
const GRID = RGBAf(0.12, 0.16, 0.20, 0.08)
const BLUE = RGBf(0.18, 0.40, 0.70)
const ORANGE = RGBf(0.88, 0.43, 0.12)
const TEAL = RGBf(0.05, 0.55, 0.56)
const PURPLE = RGBf(0.45, 0.34, 0.78)
const GRAY = RGBf(0.62, 0.66, 0.72)

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

normalize_total(v, total) = v ./ sum(v) .* total

function curves(T, H; points=801)
    y = collect(range(0.0, 1.0, length=points))
    I = [sum(H[T .< yy]) for yy in y]
    W = [sum(T .< yy) / length(T) for yy in y]
    renewal = 1 .- y
    idx = findfirst(I .>= renewal)
    ystar = if idx === nothing
        1.0
    elseif idx == 1
        y[1]
    else
        y0, y1 = y[idx-1], y[idx]
        f0, f1 = I[idx-1] - renewal[idx-1], I[idx] - renewal[idx]
        y0 - f0 * (y1 - y0) / max(f1 - f0, eps())
    end
    Wstar = sum(T .< ystar) / length(T)
    Istar = sum(H[T .< ystar])
    fragility = sum(H[abs.(T .- ystar) .< 0.04]) / 0.08
    return (; y, I, W, renewal, ystar, Wstar, Istar, fragility)
end

function variant(name, family, T, H, color; linestyle=:solid, note="")
    return (; name, family, T, H, color, linestyle, note, curve=curves(T, H))
end

function same_mean_variants(; N=220, total_impact=1.34)
    r = collect(range(1 / (N + 1), 1 - 1 / (N + 1), length=N))
    H_even = fill(total_impact / N, N)

    T_spread = 0.08 .+ 0.84 .* r
    ncluster = round(Int, 0.70 * N)
    nupper = N - ncluster
    cluster_core = 0.38 .+ 0.035 .* collect(range(-1.0, 1.0, length=ncluster))
    upper_center = (0.50 * N - sum(cluster_core)) / nupper
    cluster_upper = upper_center .+ 0.055 .* collect(range(-1.0, 1.0, length=nupper))
    T_cluster = sort(vcat(cluster_core, cluster_upper))

    H_tail = normalize_total(0.20 .+ 6.8 .* exp.(-((r .- 0.16) ./ 0.075) .^ 2), total_impact)

    half = div(N, 2)
    z1 = collect(range(-1.0, 1.0, length=half))
    z2 = collect(range(-1.0, 1.0, length=N - half))
    T_bimodal = vcat(0.28 .+ 0.055 .* z1, 0.72 .+ 0.055 .* z2)
    T_unimodal = 0.24 .+ 0.52 .* r

    T_cov = 0.08 .+ 0.84 .* r
    H_ranked = normalize_total(0.26 .+ 2.0 .* r .^ 2.25, total_impact)

    return [
        variant("spread", "clustering", T_spread, H_even, TEAL; note="spread thresholds"),
        variant("clustered", "clustering", T_cluster, H_even, ORANGE; note="cluster near crossing"),
        variant("even impact", "fat tail", T_spread, H_even, GRAY; linestyle=:dash, note="even H_i"),
        variant("fat tail", "fat tail", T_spread, H_tail, PURPLE; note="few high-H users"),
        variant("unimodal", "bimodality", T_unimodal, H_even, GRAY; linestyle=:dash, note="single group"),
        variant("bimodal", "bimodality", T_bimodal, H_even, TEAL; note="two social groups"),
        variant("positive ordering", "covariance", T_cov, H_ranked, BLUE; note="high H exits early"),
        variant("negative ordering", "covariance", T_cov, reverse(H_ranked), ORANGE; note="high H remains"),
    ]
end

function draw_phase_panel!(ax, vars; tag, title, subtitle, show_renewal_label=false, ylimit=1.42)
    style_axis!(ax)
    ax.title = "$tag  $title"
    ax.xlabel = "Resource level, y"
    ax.ylabel = "cumulative impact / renewal"
    base_y = vars[1].curve.y
    lines!(ax, base_y, 1 .- base_y; color=BLUE, linewidth=2.4)

    for v in vars
        c = v.curve
        lines!(ax, c.y, c.I; color=v.color, linewidth=3.0, linestyle=v.linestyle)
        scatter!(ax, [c.ystar], [c.Istar]; color=v.color, markersize=10,
            strokecolor=:white, strokewidth=0.8)
        vlines!(ax, [c.ystar]; color=withalpha(v.color, 0.45), linestyle=:dash, linewidth=1.1)
    end

    text!(ax, 0.04, ylimit * 0.93; text=subtitle, fontsize=11.5, color=MUTED)
    show_renewal_label && text!(ax, 0.10, 0.92; text="renewal, 1-y", fontsize=11, color=BLUE)
    xlims!(ax, 0, 1)
    ylims!(ax, 0, ylimit)
    ax.xticks = 0:0.25:1
    ax.yticks = 0:0.5:1.5
    return ax
end

function draw_threshold_rug!(ax, v; ybase=0.035, scale=13.0)
    T, H = v.T, v.H
    for i in eachindex(T)
        lines!(ax, [T[i], T[i]], [0, ybase + scale * H[i]];
            color=withalpha(v.color, 0.20), linewidth=0.8)
    end
end

function local_net_pressure(v, x)
    c = curves(v.T, v.H; points=1601)
    [sum(v.H[v.T .< yy]) - (1 - yy) for yy in x]
end

"""
    figure3_same_means_different_futures(; outdir=joinpath(@__DIR__, "figures"), save_outputs=true)

Create the combined main-text Figure 3 draft: same mean threshold and same
mean impact capacity, but different futures because spread, tails, bimodality,
clustering, and ordering/covariance change the cumulative impact geometry.
"""
function figure3_same_means_different_futures(; outdir=joinpath(@__DIR__, "figures"), save_outputs=true)
    vars = same_mean_variants()
    byname = Dict(v.name => v for v in vars)
    selected = [
        byname["spread"], byname["clustered"],
        byname["even impact"], byname["fat tail"],
        byname["unimodal"], byname["bimodal"],
        byname["positive ordering"], byname["negative ordering"],
    ]

    fig = Figure(size=(1450, 1020), backgroundcolor=:white, fontsize=16)
    Label(fig[0, 1:3], "Same means, different futures";
        fontsize=28, font=:bold, color=DARK, tellwidth=false)
    Label(fig[1, 1:3],
        "All examples hold mean exit threshold and mean impact capacity fixed; only distributional shape or ordering changes.";
        fontsize=13.5, color=MUTED, tellwidth=false)

    ax_a = Axis(fig[2, 1])
    draw_phase_panel!(ax_a, [byname["spread"], byname["clustered"]];
        tag="A", title="Clusters near the attractor", subtitle="many users enter/exit together", show_renewal_label=true)
    draw_threshold_rug!(ax_a, byname["clustered"])
    text!(ax_a, byname["clustered"].curve.ystar + 0.02, 0.18;
        text="cliff-like impact", fontsize=11.5, color=ORANGE)
    text!(ax_a, byname["spread"].curve.ystar + 0.02, 0.34;
        text="gradual impact", fontsize=11.5, color=TEAL)

    ax_b = Axis(fig[2, 2])
    draw_phase_panel!(ax_b, [byname["even impact"], byname["fat tail"]];
        tag="B", title="Fat-tailed impact capacity", subtitle="few high-H users can set y*")
    draw_threshold_rug!(ax_b, byname["fat tail"]; scale=20.0)
    text!(ax_b, 0.14, 1.05; text="upper impact tail active", fontsize=11.5, color=PURPLE)

    ax_c = Axis(fig[2, 3])
    draw_phase_panel!(ax_c, [byname["unimodal"], byname["bimodal"]];
        tag="C", title="Bimodal social groups", subtitle="same mean, two response regimes")
    vspan!(ax_c, 0.22, 0.34; color=withalpha(TEAL, 0.07))
    vspan!(ax_c, 0.66, 0.78; color=withalpha(PURPLE, 0.06))
    text!(ax_c, 0.20, 0.20; text="group 1", fontsize=11, color=TEAL)
    text!(ax_c, 0.68, 0.20; text="group 2", fontsize=11, color=PURPLE)

    ax_d = Axis(fig[3, 1])
    draw_phase_panel!(ax_d, [byname["positive ordering"], byname["negative ordering"]];
        tag="D", title="Ordering / covariance", subtitle="same marginals, different pairing")
    text!(ax_d, 0.10, 1.06; text="high H exits early", fontsize=11.5, color=BLUE)
    text!(ax_d, 0.48, 1.18; text="high H remains active", fontsize=11.5, color=ORANGE)

    ax_e = Axis(fig[3, 2],
        title="E  Attractors differ while means match",
        xlabel="distributional case",
        ylabel="resource attractor, y*")
    style_axis!(ax_e)
    cases = [
        byname["spread"], byname["clustered"], byname["fat tail"],
        byname["bimodal"], byname["positive ordering"], byname["negative ordering"],
    ]
    xs = 1:length(cases)
    ys = [v.curve.ystar for v in cases]
    barplot!(ax_e, xs, ys; color=[withalpha(v.color, 0.72) for v in cases], width=0.58)
    scatter!(ax_e, xs, ys; color=[v.color for v in cases], markersize=11,
        strokecolor=:white, strokewidth=0.8)
    hlines!(ax_e, [mean(cases[1].T)]; color=(MUTED, 0.55), linestyle=:dash, linewidth=1.2)
    text!(ax_e, 0.85, 0.52; text="common mean T", fontsize=10.5, color=MUTED)
    ax_e.xticks = (collect(xs), ["spread", "cluster", "tail", "bimodal", "+cov", "-cov"])
    xlims!(ax_e, 0.35, length(cases) + 0.65)
    ylims!(ax_e, 0, 1)
    ax_e.yticks = 0:0.25:1

    ax_f = Axis(fig[3, 3],
        title="F  Robustness is local curve geometry",
        xlabel="small resource perturbation around y*",
        ylabel="net pressure: I(y) - (1-y)")
    style_axis!(ax_f)
    focus = [byname["spread"], byname["clustered"], byname["negative ordering"]]
    for v in focus
        c = v.curve
        xlocal = collect(range(max(0, c.ystar - 0.12), min(1, c.ystar + 0.12), length=220))
        lines!(ax_f, xlocal .- c.ystar, local_net_pressure(v, xlocal);
            color=v.color, linewidth=3.0, linestyle=v.linestyle)
        scatter!(ax_f, [0.0], [0.0]; color=v.color, markersize=9, strokecolor=:white, strokewidth=0.8)
    end
    hlines!(ax_f, [0.0]; color=(DARK, 0.28), linestyle=:dash, linewidth=1.2)
    vlines!(ax_f, [0.0]; color=(DARK, 0.20), linestyle=:dash, linewidth=1.0)
    text!(ax_f, -0.105, 0.16; text="broad / robust", fontsize=11, color=TEAL)
    text!(ax_f, 0.035, -0.26; text="cliff-like / fragile", fontsize=11, color=ORANGE)
    text!(ax_f, 0.015, 0.31; text="ordering can amplify pressure", fontsize=11, color=ORANGE)
    xlims!(ax_f, -0.13, 0.13)

    elements = [
        LineElement(color=BLUE, linewidth=3),
        LineElement(color=ORANGE, linewidth=3),
        LineElement(color=TEAL, linewidth=3),
        LineElement(color=PURPLE, linewidth=3),
        LineElement(color=GRAY, linewidth=3, linestyle=:dash),
    ]
    labels = ["renewal / positive covariance", "cluster or negative covariance", "spread / bimodal", "fat tail", "same-mean reference"]
    Legend(fig[4, 1:3], elements, labels; orientation=:horizontal, framevisible=false,
        tellwidth=false, labelsize=12.3, patchsize=(24, 12))

    rowsize!(fig.layout, 0, Auto(0.30))
    rowsize!(fig.layout, 1, Auto(0.18))
    rowsize!(fig.layout, 2, Relative(0.48))
    rowsize!(fig.layout, 3, Relative(0.48))
    rowsize!(fig.layout, 4, Auto(0.18))
    colgap!(fig.layout, 28)
    rowgap!(fig.layout, 17)

    paths = String[]
    if save_outputs
        isdir(outdir) || mkpath(outdir)
        png = joinpath(outdir, "figure3_same_means_different_futures.png")
        pdf = joinpath(outdir, "figure3_same_means_different_futures.pdf")
        save(png, fig, px_per_unit=2)
        save(pdf, fig)
        append!(paths, [png, pdf])
    end

    return fig, paths
end

if abspath(PROGRAM_FILE) == @__FILE__
    _, paths = figure3_same_means_different_futures()
    println("Wrote:")
    foreach(p -> println("  ", p), paths)
end
