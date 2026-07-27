using SED
using CairoMakie
using LaTeXStrings
using Statistics

CairoMakie.activate!()

const FIGURE_DIR = normpath(joinpath(@__DIR__, "..", "figures"))
mkpath(FIGURE_DIR)

const ORANGE = Makie.RGBf(0.93, 0.49, 0.10)
const BLUE = Makie.RGBf(0.20, 0.43, 0.72)
const GREEN = Makie.RGBf(0.16, 0.55, 0.36)
const RED = Makie.RGBf(0.78, 0.25, 0.23)
const PURPLE = Makie.RGBf(0.49, 0.34, 0.70)
const GRAY = Makie.RGBf(0.68, 0.70, 0.73)
const DARK = Makie.RGBf(0.12, 0.14, 0.17)
const GRID = Makie.RGBAf(0.12, 0.14, 0.17, 0.10)

function paper_theme()
    Theme(
        fontsize=25,
        font="Arial",
        Axis=(
            backgroundcolor=:white,
            xgridcolor=GRID,
            ygridcolor=GRID,
            xgridwidth=1,
            ygridwidth=1,
            spinewidth=1.2,
            xticklabelsize=21,
            yticklabelsize=21,
            xlabelsize=25,
            ylabelsize=25,
            titlesize=27,
            titlefont=:bold,
        ),
    )
end

function teaching_population(; α=0.12)
    thresholds = [0.08, 0.14, 0.20, 0.27, 0.34, 0.42, 0.51, 0.62, 0.76, 0.90]
    potentials = [0.08, 0.11, 0.07, 0.14, 0.10, 0.16, 0.09, 0.13, 0.12, 0.10]
    N = length(thresholds)
    s = scenario((;
        N,
        α,
        w̃=dist(data=thresholds),
        ū=dist(data=potentials),
        R=ones(N),
    ))
    sample!(s)
    return s, thresholds, potentials
end

function attractor_data(s, potentials; t_end=2500.0)
    sol = sim(s; t_end)
    N = s.N
    ystar = sol[N + 1, end - 2]
    pstar = sum(sol[1:N, end - 2] ./ potentials) / N
    return sol, ystar, pstar
end

function panel_label!(layout, text)
    Label(layout, text, halign=:left, valign=:top, fontsize=28, font=:bold,
        tellwidth=false, tellheight=false, padding=(4, 0, 0, 0))
end

function save_figure(fig, stem)
    save(joinpath(FIGURE_DIR, stem * ".pdf"), fig)
    save(joinpath(FIGURE_DIR, stem * ".png"), fig; px_per_unit=2)
end

function attractor_construction_figure()
    s, thresholds, potentials = teaching_population()
    sol, ystar, pstar = attractor_data(s, potentials)
    N = length(thresholds)
    ygrid = range(0.0, 1.0; length=801)
    participation = [Γ(y, s) for y in ygrid]
    required = [Φ(y, s) for y in ygrid]
    active = thresholds .< ystar
    ordered_cumulative = cumsum(potentials)
    pressure = 1 - ystar
    full = count(<(pressure), ordered_cumulative)
    marginal_fraction = full == 0 ? pressure / potentials[1] :
        (pressure - ordered_cumulative[full]) / potentials[full + 1]
    marginal_position = (full + marginal_fraction) / N

    fig = with_theme(paper_theme()) do
        Figure(size=(1900, 1030), backgroundcolor=:white)
    end

    ax1 = Axis(fig[1, 1], title="1. Order actors by exit threshold",
        xlabel=L"\mathrm{exit\ threshold},\ \theta_i",
        ylabel=L"\mathrm{impact\ potential},\ \bar{u}_i",
        limits=(0, 1, 0, 0.19))
    for i in eachindex(thresholds)
        color = isapprox(thresholds[i], ystar; atol=0.01) ? DARK : (active[i] ? ORANGE : GRAY)
        lines!(ax1, [thresholds[i], thresholds[i]], [0, potentials[i]],
            color=color, linewidth=4)
        scatter!(ax1, [thresholds[i]], [potentials[i]], color=color, markersize=14)
    end
    vlines!(ax1, [ystar], color=DARK, linestyle=:dash, linewidth=2)
    text!(ax1, 0.16, 0.176, text="active at y*", color=ORANGE, fontsize=22, align=(:center, :top))
    text!(ax1, 0.72, 0.176, text="exited at y*", color=:gray40, fontsize=22, align=(:center, :top))
    text!(ax1, ystar + 0.015, 0.165, text="marginal", color=DARK, fontsize=20,
        align=(:left, :bottom), rotation=π / 2)
    text!(ax1, ystar + 0.015, 0.015, text=L"y^*", color=DARK, fontsize=23)
    panel_label!(fig[1, 1], "A")

    ax2 = Axis(fig[1, 2], title="2. Count who remains willing to harvest",
        xlabel="resource density, y",
        ylabel="Participation (share of all actors)",
        limits=(0, 1, 0, 1.02))
    stairs!(ax2, ygrid, participation, color=ORANGE, linewidth=5, step=:post)
    vlines!(ax2, [ystar], color=DARK, linestyle=:dash, linewidth=2)
    hlines!(ax2, [pstar], color=DARK, linestyle=:dot, linewidth=2)
    scatter!(ax2, [ystar], [pstar], color=DARK, markersize=17)
    text!(ax2, 0.61, 0.82, text=L"P_-(y)=N^{-1}\sum_i\mathbf{1}(\theta_i<y)",
        color=ORANGE, fontsize=23, align=(:center, :center))
    panel_label!(fig[1, 2], "B")

    ax3 = Axis(fig[2, 1], title="3. Accumulate impact in the same order",
        xlabel="actors ordered by increasing θᵢ (fraction)",
        ylabel="cumulative impact", limits=(0, 1, 0, 1.15))
    fractions = collect(0:N) ./ N
    stairs!(ax3, fractions, [0.0; ordered_cumulative], color=BLUE, linewidth=5, step=:post)
    hlines!(ax3, [pressure], color=RED, linewidth=3, linestyle=:dash)
    vlines!(ax3, [marginal_position], color=DARK, linewidth=2, linestyle=:dot)
    scatter!(ax3, [marginal_position], [pressure], color=DARK, markersize=17)
    text!(ax3, 0.98, pressure + 0.035, text=L"1-y^*", color=RED, fontsize=23,
        align=(:right, :bottom))
    text!(ax3, marginal_position + 0.02, 0.10,
        text="fraction needed", color=DARK, fontsize=21, rotation=π / 2)
    panel_label!(fig[2, 1], "C")

    ax4 = Axis(fig[2, 2], title="4. Read the attractor from the crossing",
        xlabel="resource density, y",
        ylabel="Participation (share of all actors)",
        limits=(0, 1, 0, 1.02))
    lines!(ax4, ygrid, participation, color=ORANGE, linewidth=5)
    lines!(ax4, ygrid, required, color=BLUE, linewidth=5, linestyle=:dash)
    vlines!(ax4, [ystar], color=DARK, linestyle=:dot, linewidth=2)
    scatter!(ax4, [ystar], [pstar], color=DARK, markersize=21)
    text!(ax4, 0.73, 0.88, text="participation  P(y)", color=ORANGE,
        fontsize=23, align=(:center, :center))
    text!(ax4, 0.70, 0.17, text="required participation  I(y)", color=BLUE,
        fontsize=23, align=(:center, :center))
    text!(ax4, ystar + 0.025, pstar + 0.025,
        text="attractor  y* = $(round(ystar, digits=2))", color=DARK, fontsize=22)
    panel_label!(fig[2, 2], "D")

    colgap!(fig.layout, 55)
    rowgap!(fig.layout, 55)
    save_figure(fig, "figureS1_attractor_construction")
    return fig
end

function dynamics_figure()
    base_s, _, potentials = teaching_population()
    _, ystar, pstar = attractor_data(base_s, potentials)
    ygrid = range(0.0, 1.0; length=801)
    participation = [Γ(y, base_s) for y in ygrid]
    required = [Φ(y, base_s) for y in ygrid]
    rates = [0.01, 0.10, 0.70]
    colors = [GREEN, PURPLE, RED]
    labels = ["slow", "intermediate", "fast"]
    sols = [sim(change(base_s, α=rate); t_end=3000.0) for rate in rates]

    fig = with_theme(paper_theme()) do
        Figure(size=(1800, 1420), backgroundcolor=:white)
    end

    ax1 = Axis(fig[1, 1:2], title="Same attractor, different approaches",
        xlabel="resource density, y",
        ylabel="Participation (share of all actors)",
        limits=(0, 1, 0, 1.02))
    lines!(ax1, ygrid, participation, color=ORANGE, linewidth=3, alpha=0.45)
    lines!(ax1, ygrid, required, color=BLUE, linewidth=3, linestyle=:dash, alpha=0.45)
    for (sol, rate, color, label) in zip(sols, rates, colors, labels)
        N = base_s.N
        path_y = sol[N + 1, :]
        path_p = [sum(u[1:N] ./ potentials) / N for u in sol.u]
        lines!(ax1, path_y, path_p, color=color, linewidth=4)
        scatter!(ax1, [path_y[1]], [path_p[1]], color=color, markersize=12, marker=:rect)
        text!(ax1, path_y[min(end, 8)] + 0.015, path_p[min(end, 8)],
            text="$label  α=$(rate)", color=color, fontsize=21)
    end
    scatter!(ax1, [ystar], [pstar], color=DARK, markersize=22)
    text!(ax1, ystar + 0.025, pstar + 0.025, text="shared attractor", color=DARK, fontsize=22)
    panel_label!(fig[1, 1:2], "A")

    ax2 = Axis(fig[2, 1], title="Resource trajectories",
        xlabel=L"\mathrm{dimensionless\ time},\ \tau+1\ \mathrm{(log\ scale)}",
        ylabel="resource density, y", xscale=log10, limits=(1, 3001, 0.30, 1.02))
    for (sol, color, label) in zip(sols, colors, labels)
        lines!(ax2, sol.t .+ 1, sol[base_s.N + 1, :], color=color, linewidth=4, label=label)
    end
    hlines!(ax2, [ystar], color=DARK, linestyle=:dot, linewidth=2)
    axislegend(ax2, position=:rt, framevisible=false, labelsize=21)
    panel_label!(fig[2, 1], "B")

    ax3 = Axis(fig[2, 2], title="Participation trajectories",
        xlabel=L"\mathrm{dimensionless\ time},\ \tau+1\ \mathrm{(log\ scale)}",
        ylabel="Participation (share of all actors)",
        xscale=log10, limits=(1, 3001, 0, 0.95))
    for (sol, color) in zip(sols, colors)
        path_p = [sum(u[1:base_s.N] ./ potentials) / base_s.N for u in sol.u]
        lines!(ax3, sol.t .+ 1, path_p, color=color, linewidth=4)
    end
    hlines!(ax3, [pstar], color=DARK, linestyle=:dot, linewidth=2)
    panel_label!(fig[2, 2], "C")

    colgap!(fig.layout, 55)
    rowgap!(fig.layout, 65)
    save_figure(fig, "figureS2_adjustment_dynamics")
    return fig
end

function rights_allocation_figure()
    thresholds = collect(range(0.12, 0.78; length=12))
    potentials = [0.07, 0.11, 0.06, 0.13, 0.09, 0.16,
        0.08, 0.14, 0.10, 0.12, 0.07, 0.09]
    N = length(thresholds)
    actors = collect(1:N)
    base_s = scenario((;
        N,
        α=0.08,
        w̃=dist(data=thresholds),
        ū=dist(data=potentials),
        R=ones(N),
    ))
    sample!(base_s)

    exclusive_s = scenario(base_s; policy=ExclusiveUseRights(:top, false))
    exclusive_p = exclusive_s.regulate(exclusive_s, 0.33)
    exclusion_mask = exclusive_p.R
    right_fraction = [0.65, 0.75, 0.55, 0.70, 0.60, 0.80,
        0.65, 0.55, 0.0, 0.0, 0.0, 0.0]
    exclusive_rights = (1 .- exclusion_mask) .* right_fraction .* potentials
    exclusive_use = [0.040, 0.090, 0.030, 0.080, 0.060, 0.120,
        0.040, 0.100, 0.020, 0.000, 0.030, 0.000]
    excluded = findall(>(0.5), exclusion_mask)
    sanctioned = exclusive_use .> exclusive_rights .+ 1e-8

    regulation = 0.60
    equal_s = scenario(base_s;
        policy=TradableUseRights(:effort, 0.08, 0.0, false))
    historical_s = scenario(base_s;
        policy=TradableUseRights(:effort, 0.08, 0.0, true))
    equal_p = equal_s.regulate(equal_s, regulation)
    historical_p = historical_s.regulate(historical_s, regulation)
    equal_sol = sim(equal_s; regulation, t_end=5000.0)
    historical_sol = sim(historical_s; regulation, t_end=5000.0)
    equal_use = equal_sol[1:N, end - 2]
    historical_use = historical_sol[1:N, end - 2]
    equal_price = equal_sol[N + 2, end - 2]
    historical_price = historical_sol[N + 2, end - 2]
    equal_transfer = (equal_p.R .- equal_use) .* equal_price
    historical_transfer = (historical_p.R .- historical_use) .* historical_price
    quota = sum(equal_p.R)
    ystar = 0.5 * (equal_sol[N + 1, end - 2] + historical_sol[N + 1, end - 2])
    @assert isapprox(sum(equal_p.R), sum(historical_p.R); atol=1e-10)
    @assert maximum(abs.(equal_use .- historical_use)) < 5e-4
    @assert abs(sum(equal_transfer)) < 1e-4
    @assert abs(sum(historical_transfer)) < 1e-4

    exclusive_fig = with_theme(paper_theme()) do
        Figure(size=(1900, 760), backgroundcolor=:white)
    end
    tradable_fig = with_theme(paper_theme()) do
        Figure(size=(1900, 760), backgroundcolor=:white)
    end

    ymax = 1.22 * maximum(potentials)
    actor_ticks = ([1, N], ["low θᵢ", "high θᵢ"])

    ax1 = Axis(exclusive_fig[1, 1], title="Exclusive rights: assign a sanctioned-use threshold",
        xlabel="actors ordered by exit threshold",
        ylabel="activity units", limits=(0.3, N + 0.7, 0, ymax),
        xticks=actor_ticks)
    barplot!(ax1, actors, potentials; color=Makie.RGBAf(GRAY, 0.34),
        strokecolor=GRAY, strokewidth=1.3, width=0.72)
    barplot!(ax1, actors, exclusive_rights; color=Makie.RGBAf(BLUE, 0.88),
        width=0.48)
    scatter!(ax1, excluded, fill(0.008, length(excluded)); marker=:xcross,
        color=RED, markersize=23, strokewidth=3)
    text!(ax1, 8.15, 0.188;
        text="gray = impact potential  ūᵢ\nblue = assigned right  Rᵢ",
        color=DARK, fontsize=21, align=(:left, :top))
    text!(ax1, 10.5, 0.045; text="excluded\nRᵢ = 0", color=RED,
        fontsize=21, font=:bold, align=(:center, :bottom))
    text!(ax1, 3.7, 0.185; text="right holder:  0 < Rᵢ ≤ ūᵢ", color=BLUE,
        fontsize=22, font=:bold, align=(:center, :bottom))
    panel_label!(exclusive_fig[1, 1], "A")

    ax2 = Axis(exclusive_fig[1, 2], title="Sanction applies whenever realized use exceeds Rᵢ",
        xlabel="same actors",
        ylabel="activity units", limits=(0.3, N + 0.7, 0, ymax),
        xticks=actor_ticks)
    barplot!(ax2, actors, potentials; color=Makie.RGBAf(GRAY, 0.22),
        strokecolor=GRAY, strokewidth=1.1, width=0.72)
    use_colors = [sanctioned[i] ? RED : ORANGE for i in actors]
    barplot!(ax2, actors, exclusive_use; color=use_colors, width=0.44)
    right_segments = Point2f[]
    for i in actors
        push!(right_segments, Point2f(i - 0.31, exclusive_rights[i]))
        push!(right_segments, Point2f(i + 0.31, exclusive_rights[i]))
    end
    linesegments!(ax2, right_segments; color=BLUE, linewidth=4)
    text!(ax2, 1.0, 0.188;
        text="blue tick = assigned right  Rᵢ\norange = uᵢ ≤ Rᵢ; red = uᵢ > Rᵢ",
        color=DARK, fontsize=21, align=(:left, :top))
    text!(ax2, 8.7, 0.158;
        text="sanction applies even when\nRᵢ < uᵢ ≤ ūᵢ",
        color=RED, fontsize=21, font=:bold, align=(:center, :top))
    text!(ax2, 6.5, 0.018; text="uᵢ > Rᵢ  ⇒  −Sᵢuᵢ", color=DARK,
        fontsize=24, font=:bold, align=(:center, :bottom))
    panel_label!(exclusive_fig[1, 2], "B")

    ax3 = Axis(tradable_fig[1, 1], title="Tradable rights: two initial allocations of the same quota",
        xlabel="actors ordered by exit threshold",
        ylabel="initial right, Rᵢ", limits=(0.3, N + 0.7, 0, 0.105),
        xticks=actor_ticks)
    barplot!(ax3, actors .- 0.19, equal_p.R; color=BLUE, width=0.34)
    barplot!(ax3, actors .+ 0.19, historical_p.R; color=ORANGE, width=0.34)
    text!(ax3, 1.0, 0.099;
        text="blue = equal use rights\norange = historical use rights",
        color=DARK, fontsize=21, align=(:left, :top))
    text!(ax3, 7.1, 0.099;
        text="ΣRᵢ = Q = $(round(quota, digits=2))\nfor both allocations",
        color=DARK, fontsize=22, font=:bold, align=(:left, :top))
    panel_label!(tradable_fig[1, 1], "A")

    transfer_lim = 1.28 * maximum(abs, [equal_transfer; historical_transfer])
    ax4 = Axis(tradable_fig[1, 2], title="Same final use, different rent transfers",
        xlabel="same actors", ylabel=L"\mathrm{transfer},\ (R_i-u_i)\phi",
        limits=(0.3, N + 0.7, -transfer_lim, transfer_lim),
        xticks=actor_ticks)
    hlines!(ax4, [0.0], color=DARK, linewidth=1.6)
    barplot!(ax4, actors .- 0.19, equal_transfer; color=BLUE, width=0.34)
    barplot!(ax4, actors .+ 0.19, historical_transfer; color=ORANGE, width=0.34)
    text!(ax4, 1.0, 0.90transfer_lim;
        text="positive: net seller receives rent", color=GREEN,
        fontsize=21, align=(:left, :top))
    text!(ax4, 1.0, -0.90transfer_lim;
        text="negative: net buyer pays for use", color=RED,
        fontsize=21, align=(:left, :bottom))
    text!(ax4, 7.05, 0.90transfer_lim;
        text="same uᵢ and y* = $(round(ystar, digits=2))\nΣ(Rᵢ-uᵢ)ϕ ≈ 0",
        color=DARK, fontsize=22, font=:bold, align=(:left, :top))
    panel_label!(tradable_fig[1, 2], "B")

    colgap!(exclusive_fig.layout, 70)
    colgap!(tradable_fig.layout, 70)
    save_figure(exclusive_fig, "figureS3_exclusive_rights_allocation")
    save_figure(tradable_fig, "figureS4_tradable_rights_allocation")
    return exclusive_fig, tradable_fig
end

function incentive_switch_figure()
    w = exp.(range(log(0.45), log(2.6); length=240))
    η_no = 0.65
    η_switch = 1.35
    q_no = w .^ η_no
    q_switch = w .^ η_switch
    q_no ./= median(q_no)
    q_switch ./= median(q_switch)
    pK = 3.0
    ebar_over_r = 0.16
    theta_no = w ./ (pK .* q_no)
    theta_switch = w ./ (pK .* q_switch)
    potential_no = ebar_over_r .* q_no
    potential_switch = ebar_over_r .* q_switch

    fig = with_theme(paper_theme()) do
        Figure(size=(1800, 1420), backgroundcolor=:white)
    end

    ax1 = Axis(fig[1, 1], title="Efficiency relative to outside opportunity",
        xlabel=L"\mathrm{outside\ opportunity},\ w", ylabel=L"\mathrm{harvesting\ efficiency},\ q(w)")
    lines!(ax1, w, q_no, color=BLUE, linewidth=5)
    lines!(ax1, w, q_switch, color=ORANGE, linewidth=5)
    text!(ax1, 2.42, q_no[end], text=L"\eta=0.65<1", color=BLUE, fontsize=22,
        align=(:right, :bottom))
    text!(ax1, 2.42, q_switch[end], text=L"\eta=1.35>1", color=ORANGE, fontsize=22,
        align=(:right, :bottom))
    panel_label!(fig[1, 1], "A")

    ax2 = Axis(fig[1, 2], title="The exit-threshold ordering can reverse",
        xlabel=L"\mathrm{outside\ opportunity},\ w",
        ylabel=L"\mathrm{exit\ threshold},\ \theta(w)")
    lines!(ax2, w, theta_no, color=BLUE, linewidth=5)
    lines!(ax2, w, theta_switch, color=ORANGE, linewidth=5)
    text!(ax2, 1.68, 0.445, text="outside opportunity dominates\nθ rises with w",
        color=BLUE, fontsize=21, align=(:center, :center))
    text!(ax2, 1.25, theta_switch[120], text="efficiency dominates\nθ falls with w",
        color=ORANGE, fontsize=21, align=(:left, :top))
    panel_label!(fig[1, 2], "B")

    ax3 = Axis(fig[2, 1:2], title="The resulting threshold-impact ordering",
        xlabel=L"\mathrm{exit\ threshold},\ \theta",
        ylabel=L"\mathrm{impact\ potential},\ \bar{u}")
    lines!(ax3, theta_no, potential_no, color=BLUE, linewidth=5)
    lines!(ax3, theta_switch, potential_switch, color=ORANGE, linewidth=5)
    scatter!(ax3, theta_no[1:20:end], potential_no[1:20:end], color=BLUE, markersize=10)
    scatter!(ax3, theta_switch[1:20:end], potential_switch[1:20:end],
        color=ORANGE, markersize=10)
    text!(ax3, quantile(theta_no, 0.72), quantile(potential_no, 0.30),
        text="positive ordering", color=BLUE, fontsize=22)
    text!(ax3, quantile(theta_switch, 0.18), quantile(potential_switch, 0.78),
        text="reversed ordering", color=ORANGE, fontsize=22)
    panel_label!(fig[2, 1:2], "C")

    Label(fig[3, 1:2],
        L"\mathrm{ordering\ switches\ when}\quad\frac{d\log q}{d\log w}>1",
        fontsize=29, tellheight=true, padding=(0, 0, 8, 0))
    colgap!(fig.layout, 55)
    rowgap!(fig.layout, 55)
    save_figure(fig, "figureS5_incentive_switch")
    return fig
end

attractor_construction_figure()
dynamics_figure()
rights_allocation_figure()
incentive_switch_figure()
