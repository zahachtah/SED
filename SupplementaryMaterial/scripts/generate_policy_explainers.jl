#!/usr/bin/env julia

module PolicyExplainers

using CairoMakie
using Distributions: LogNormal
using LaTeXStrings
using Printf
using Statistics
using SED

CairoMakie.activate!()

const FIGURE_DIR = normpath(joinpath(@__DIR__, "..", "figures"))
const DARK = RGBf(0.10, 0.12, 0.15)
const MUTED = RGBf(0.38, 0.43, 0.51)
const GRID = RGBAf(0.12, 0.15, 0.19, 0.09)
const GRAY = RGBf(0.67, 0.70, 0.74)
const PALE_GRAY = RGBf(0.88, 0.89, 0.91)
const BLUE = RGBf(0.08, 0.39, 0.68)
const ORANGE = RGBf(0.94, 0.43, 0.06)
const GREEN = RGBf(0.10, 0.55, 0.27)
const RED = RGBf(0.80, 0.16, 0.17)
const PURPLE = RGBf(0.45, 0.31, 0.68)

withalpha(c, a) = RGBAf(c.r, c.g, c.b, a)

function explainer_theme()
    Theme(
        fontsize=27,
        font="Arial",
        Axis=(
            backgroundcolor=:white,
            xgridcolor=GRID,
            ygridcolor=GRID,
            spinewidth=1.0,
            xticklabelsize=22,
            yticklabelsize=22,
            xlabelsize=26,
            ylabelsize=26,
            titlesize=28,
            titlefont=:bold,
        ),
    )
end

function hidden_axis(layout; title="")
    ax = Axis(layout; title)
    hidedecorations!(ax)
    hidespines!(ax)
    xlims!(ax, 0, 1)
    ylims!(ax, 0, 1)
    return ax
end

function save_pair(fig, stem)
    mkpath(FIGURE_DIR)
    save(joinpath(FIGURE_DIR, stem * ".pdf"), fig)
    save(joinpath(FIGURE_DIR, stem * ".png"), fig; px_per_unit=2)
end

function deterministic_values(d, n)
    sample!(d, n; random=false)
    return copy(d.data)
end

function policy_population(; n=80)
    threshold_source = dist(distribution=LogNormal, min=0.08, max=0.92, random=false)
    impact_source = dist(distribution=LogNormal, min=0.18, max=1.80, random=false)
    thresholds = deterministic_values(threshold_source, n)
    impacts = reverse(deterministic_values(impact_source, n))
    impacts .*= 1.18 / sum(impacts)

    base_s = scenario(base(N=n);
        α=0.08,
        w̃=dist(data=thresholds),
        ū=dist(data=impacts),
        opportunities=dist(data=thresholds),
        title="Open access")
    sample!(base_s; force=true)
    return base_s, thresholds, impacts
end

steady_index(sol) = max(1, length(sol.t) - 2)
steady_state(sol) = sol.u[steady_index(sol)]
steady_time(sol) = sol.t[steady_index(sol)]

function participation(sol)
    p = sol.prob.p
    x = steady_state(sol)
    limits = p.limit(x, p, steady_time(sol))
    return mean(clamp.(x[1:p.N] ./ max.(limits, eps()), 0.0, 1.0))
end

attractor(sol) = (steady_state(sol)[sol.prob.p.N + 1], participation(sol))

function curve_data(sol; n=401)
    p = sol.prob.p
    x = steady_state(sol)
    t = steady_time(sol)
    y = collect(range(0.0, 1.0; length=n))
    participation_curve = [Γ(yy, p; x, t) for yy in y]
    sustainable_curve = [Φ(yy, p; x, t) for yy in y]
    return y, participation_curve, sustainable_curve
end

function build_policy_solutions()
    base_s, thresholds, impacts = policy_population()
    oa = sim(base_s; t_end=1600.0)
    oa_state = steady_state(oa)

    exclusive_low = sim(
        scenario(base_s; policy=ExclusiveUseRights(:bottom, false));
        regulation=0.30, start_from_OA=true, t_end=1600.0)
    exclusive_high = sim(
        scenario(base_s; policy=ExclusiveUseRights(:top, false));
        regulation=0.30, start_from_OA=true, t_end=1600.0)

    tradable_equal = sim(
        scenario(base_s; policy=TradableUseRights(:effort, 0.08, 0.0, false));
        regulation=0.50, start_from_OA=true, t_end=5000.0)
    tradable_historical = sim(
        scenario(base_s; policy=TradableUseRights(:effort, 0.08, 0.0, true));
        regulation=0.50, start_from_OA=true, t_end=5000.0)

    protected = sim(
        scenario(base_s; policy=ProtectedArea(0.30));
        regulation=0.35, start_from_OA=true, t_end=1800.0)

    royalty_rate = 0.25
    royalty_s = scenario(base_s;
        w̃=dist(data=thresholds ./ (1 - royalty_rate)),
        title="Royalty")
    sample!(royalty_s; force=true)
    royalty = sim(royalty_s;
        u0=oa_state[1:base_s.N], y0=oa_state[base_s.N + 1], t_end=1600.0)

    gear_factor = 1.35
    gear_s = scenario(base_s;
        w̃=dist(data=thresholds ./ gear_factor),
        ū=dist(data=impacts .* gear_factor),
        title="Gear subsidy")
    sample!(gear_s; force=true)
    gear = sim(gear_s;
        u0=oa_state[1:base_s.N], y0=oa_state[base_s.N + 1], t_end=1600.0)

    return (;
        base_s, thresholds, impacts, oa,
        exclusive_low, exclusive_high,
        tradable_equal, tradable_historical,
        protected, royalty, gear,
        royalty_rate, gear_factor,
    )
end

function figure_shell(title, subtitle, takeaway)
    fig = with_theme(explainer_theme()) do
        Figure(size=(1800, 1600), backgroundcolor=:white)
    end
    Label(fig[1, 1:2], title; fontsize=40, font=:bold, color=DARK,
        tellwidth=false, padding=(0, 0, 8, 18))
    Label(fig[2, 1:2], subtitle; fontsize=27, color=MUTED,
        tellwidth=false, padding=(0, 0, 6, 0))
    for (j, label) in enumerate(("1  Institutional rule", "2  What changes mathematically"))
        Label(fig[3, j], label; fontsize=27, font=:bold, color=DARK,
            tellwidth=false, halign=:left, padding=(4, 0, 6, 0))
    end
    for (j, label) in enumerate(("3  How the system geometry moves", "4  Why the outcome changes"))
        Label(fig[5, j], label; fontsize=27, font=:bold, color=DARK,
            tellwidth=false, halign=:left, padding=(4, 0, 6, 0))
    end
    Label(fig[7, 1:2], "TAKE-HOME  " * takeaway; fontsize=27, font=:bold,
        color=DARK, tellwidth=false, halign=:left, padding=(4, 0, 20, 0))
    rowsize!(fig.layout, 4, Fixed(500))
    rowsize!(fig.layout, 6, Fixed(500))
    colgap!(fig.layout, 55)
    rowgap!(fig.layout, 10)
    return fig
end

function scenario_key!(ax, entries; x=0.04, y=0.95, gap=0.075)
    for (j, (name, color)) in enumerate(entries)
        yy = y - (j - 1) * gap
        lines!(ax, [x, x + 0.08], [yy, yy]; color, linewidth=5)
        text!(ax, x + 0.10, yy; text=name, color, fontsize=20,
            font=:bold, align=(:left, :center))
    end
end

function phase_panel!(layout, oa, variants;
        colors, names, title="Simulated phase geometry")
    ax = Axis(layout; title,
        xlabel="resource level, y",
        ylabel="Participation (share of all actors)",
        xticks=0:0.5:1, yticks=0:0.5:1)
    xlims!(ax, 0, 1)
    ylims!(ax, 0, 1)

    y0, p0, i0 = curve_data(oa)
    lines!(ax, y0, p0; color=withalpha(GRAY, 0.92), linewidth=4)
    lines!(ax, y0, i0; color=withalpha(GRAY, 0.92), linewidth=3,
        linestyle=:dash)
    ystar0, pstar0 = attractor(oa)
    scatter!(ax, [ystar0], [pstar0]; color=GRAY, markersize=17,
        strokecolor=:white, strokewidth=1.2)

    for (j, sol) in enumerate(variants)
        y, pcurve, icurve = curve_data(sol)
        lines!(ax, y, pcurve; color=colors[j], linewidth=4)
        lines!(ax, y, icurve; color=colors[j], linewidth=3, linestyle=:dash)
        ystar, pstar = attractor(sol)
        scatter!(ax, [ystar], [pstar]; color=colors[j], markersize=19,
            strokecolor=:white, strokewidth=1.4)
        text!(ax, ystar + 0.018, pstar + 0.025;
            text=string(j), color=colors[j], fontsize=20, font=:bold,
            align=(:left, :bottom))
    end

    text!(ax, 0.04, 0.08;
        text="solid: participation\ndashed: sustainable participation",
        color=MUTED, fontsize=19, align=(:left, :bottom))
    entries = [("open access", GRAY); [("$(j)  $(names[j])", colors[j])
        for j in eachindex(names)]...]
    scenario_key!(ax, entries)
    return ax
end

function outcome_panel!(layout, solutions, names, colors;
        title="Simulated long-run outcome")
    ax = Axis(layout; title,
        xlabel="fraction",
        yticks=([1.0, 2.0], ["participation", "resource level"]),
        xticks=0:0.25:1)
    xlims!(ax, 0, 1.06)
    ylims!(ax, 0.52, 2.48)
    ax.ygridvisible = false
    offsets = collect(range(-0.18, 0.18; length=length(solutions)))
    for (j, sol) in enumerate(solutions)
        ystar, pstar = attractor(sol)
        values = [pstar, ystar]
        ypos = [1.0, 2.0] .+ offsets[j]
        segments = Point2f[]
        for k in 1:2
            push!(segments, Point2f(0, ypos[k]), Point2f(values[k], ypos[k]))
        end
        linesegments!(ax, segments;
            color=withalpha(colors[j], 0.55), linewidth=8)
        scatter!(ax, values, ypos; color=colors[j], markersize=16,
            label=names[j])
        for k in 1:2
            text!(ax, values[k] + 0.025, ypos[k];
                text=@sprintf("%.2f", values[k]), color=colors[j],
                fontsize=20, font=:bold, align=(:left, :center))
        end
    end
    axislegend(ax; position=:rb, framevisible=false, labelsize=15,
        patchsize=(18, 12), rowgap=2)
    return ax
end

function actor_row!(ax, y, excluded; label, color)
    n = length(excluded)
    xs = collect(range(0.08, 0.92; length=n))
    scatter!(ax, xs, fill(y, n); color=fill(withalpha(BLUE, 0.88), n),
        markersize=28)
    for i in findall(excluded)
        scatter!(ax, [xs[i]], [y]; marker=:xcross, color=RED,
            markersize=31, strokewidth=4)
    end
    text!(ax, 0.04, y + 0.105; text=label, color, fontsize=23,
        font=:bold, align=(:left, :center))
end

function exclusive_rule_panel!(layout)
    ax = hidden_axis(layout; title="Who receives an enforceable right?")
    actor_row!(ax, 0.70, [falses(8); trues(4)];
        label="1  exclude high-threshold actors", color=BLUE)
    actor_row!(ax, 0.34, [trues(4); falses(8)];
        label="2  exclude low-threshold actors", color=ORANGE)
    text!(ax, 0.08, 0.10; text="low exit threshold", color=MUTED,
        fontsize=20, align=(:left, :center))
    text!(ax, 0.92, 0.10; text="high exit threshold", color=MUTED,
        fontsize=20, align=(:right, :center))
    arrows2d!(ax, [Point2f(0.29, 0.10)], [Vec2f(0.42, 0.0)];
        color=MUTED, shaftwidth=2.5, tipwidth=13, tiplength=15)
end

function exclusive_math_panel!(layout)
    ax = hidden_axis(layout; title="Unauthorized use triggers a sanction")
    text!(ax, 0.04, 0.82;
        text=L"v_i^{\mathrm{EUR}}=v_i^{\mathrm{OA}}-S_i u_i\mathbf{1}(u_i>R_i)",
        color=DARK, fontsize=32, align=(:left, :center))
    text!(ax, 0.04, 0.60; text=L"R_i=0\quad\Rightarrow",
        color=RED, fontsize=32, align=(:left, :center))
    text!(ax, 0.44, 0.60; text="excluded",
        color=RED, fontsize=27, font=:bold, align=(:left, :center))
    text!(ax, 0.04, 0.46; text=L"R_i=\bar{u}_i\quad\Rightarrow",
        color=BLUE, fontsize=32, align=(:left, :center))
    text!(ax, 0.53, 0.46; text="authorized",
        color=BLUE, fontsize=27, font=:bold, align=(:left, :center))
    text!(ax, 0.04, 0.25;
        text="With strong enforcement, using more than Rᵢ\nis never worthwhile. The selection rule decides\nwhich impact potentials disappear from access.",
        color=MUTED, fontsize=23, align=(:left, :top))
end

function exclusive_figure(data)
    fig = figure_shell(
        "Exclusive use rights: access depends on who receives a right",
        "A strong sanction turns an allocation rule into an access rule; selecting the same number of actors can produce very different outcomes.",
        "The excluded share alone is not enough.\nOutcomes depend on which thresholds and impact potentials are removed from access.")
    exclusive_rule_panel!(fig[4, 1])
    exclusive_math_panel!(fig[4, 2])
    phase_panel!(fig[6, 1], data.oa,
        [data.exclusive_high, data.exclusive_low];
        colors=[BLUE, ORANGE],
        names=["high-threshold exclusion", "low-threshold exclusion"])
    outcome_panel!(fig[6, 2],
        [data.oa, data.exclusive_high, data.exclusive_low],
        ["open access", "high θ excluded", "low θ excluded"],
        [GRAY, BLUE, ORANGE])
    save_pair(fig, "figureS3_exclusive_policy_explainer")
    return fig
end

function tradable_rule_panel!(layout)
    ax = hidden_axis(layout; title="The same quota can have different owners")
    n = 12
    xs = collect(range(0.08, 0.92; length=n))
    equal = fill(0.10, n)
    historical = [fill(0.30, 4); zeros(n - 4)]
    barplot!(ax, xs, 0.61 .+ equal; width=0.050, color=BLUE, fillto=0.61)
    barplot!(ax, xs, 0.20 .+ historical; width=0.050, color=ORANGE, fillto=0.20)
    hlines!(ax, [0.61, 0.20]; color=withalpha(GRAY, 0.45), linewidth=1)
    text!(ax, 0.04, 0.83; text="equal rights: everyone starts with Q/N",
        color=BLUE, fontsize=23, font=:bold, align=(:left, :center))
    text!(ax, 0.04, 0.55; text="historical rights: prior users share Q",
        color=ORANGE, fontsize=23, font=:bold, align=(:left, :center))
    text!(ax, 0.50, 0.04; text="same total quota  ΣRᵢ = Q",
        color=DARK, fontsize=25, font=:bold, align=(:center, :bottom))
end

function tradable_math_panel!(layout)
    ax = hidden_axis(layout; title="Price clears excess use")
    text!(ax, 0.04, 0.84;
        text=L"v_i^{\mathrm{TUR}}=v_i^{\mathrm{OA}}+(R_i-u_i)\phi",
        color=DARK, fontsize=32, align=(:left, :center))
    text!(ax, 0.04, 0.66;
        text=L"\dot\phi=\kappa\!\left(\sum_i u_i-Q\right)",
        color=RED, fontsize=32, align=(:left, :center))
    text!(ax, 0.04, 0.49;
        text=L"\theta_i^{\mathrm{TUR}}=\theta_i+\phi",
        color=ORANGE, fontsize=32, align=(:left, :center))
    text!(ax, 0.04, 0.28;
        text="Use above Rᵢ is bought; unused Rᵢ is sold.\nWhen total use exceeds Q, price rises until\nthe common quota binds.",
        color=MUTED, fontsize=23, align=(:left, :top))
end

function transfer_axis!(layout, sol, title, thresholds; show_xlabel=false)
    p = sol.prob.p
    x = steady_state(sol)
    transfer = incomes(x, p).trade
    order = sortperm(thresholds)
    transfer = transfer[order]
    n = length(transfer)
    lim = 1.15 * maximum(abs, transfer)
    ax = Axis(layout; title, ylabel="permit rent",
        xlabel=show_xlabel ? "actors ordered by exit threshold" : "")
    barplot!(ax, 1:n, transfer;
        color=[v >= 0 ? GREEN : RED for v in transfer], width=0.86)
    hlines!(ax, [0]; color=DARK, linewidth=1.2)
    xlims!(ax, 0.5, n + 0.5)
    ylims!(ax, -lim, lim)
    ax.xticksvisible = false
    ax.xticklabelsvisible = false
    text!(ax, 0.98n, 0.88lim; text="seller +", color=GREEN,
        fontsize=18, font=:bold, align=(:right, :top))
    text!(ax, 0.98n, -0.88lim; text="buyer −", color=RED,
        fontsize=18, font=:bold, align=(:right, :bottom))
    return ax
end

function tradable_figure(data)
    fig = figure_shell(
        "Tradable use rights: the quota fixes total use; ownership fixes who receives rent",
        "A market price moves rights from initial owners to final users.\nEqual and historical endowments can share one ecological outcome but not one income distribution.",
        "The aggregate quota and price determine final use;\nthe initial Rᵢ allocation determines who pays and who receives scarcity rent.")
    tradable_rule_panel!(fig[4, 1])
    tradable_math_panel!(fig[4, 2])
    phase_panel!(fig[6, 1], data.oa, [data.tradable_equal];
        colors=[ORANGE], names=["quota equilibrium"])

    rent_grid = GridLayout(fig[6, 2])
    transfer_axis!(rent_grid[1, 1], data.tradable_equal,
        "equal initial rights", data.thresholds)
    transfer_axis!(rent_grid[2, 1], data.tradable_historical,
        "historical initial rights", data.thresholds; show_xlabel=true)
    rowgap!(rent_grid, 6)
    y_equal, p_equal = attractor(data.tradable_equal)
    Label(rent_grid[0, 1], @sprintf("same final ecology:  y* = %.2f, participation = %.2f",
        y_equal, p_equal); fontsize=21, font=:bold, color=DARK, tellwidth=false)
    save_pair(fig, "figureS4_tradable_policy_explainer")
    return fig
end

function protected_rule_panel!(layout)
    ax = hidden_axis(layout; title="Close habitat, then receive spillover")
    poly!(ax, Rect2f(0.05, 0.19, 0.35, 0.62); color=withalpha(GREEN, 0.18),
        strokecolor=GREEN, strokewidth=2)
    poly!(ax, Rect2f(0.40, 0.19, 0.55, 0.62); color=withalpha(BLUE, 0.09),
        strokecolor=withalpha(BLUE, 0.35), strokewidth=2)
    text!(ax, 0.225, 0.73; text="protected\nno harvest", color=GREEN,
        fontsize=24, font=:bold, align=(:center, :center))
    text!(ax, 0.69, 0.73; text="exploited\nharvest", color=BLUE,
        fontsize=24, font=:bold, align=(:center, :center))
    px = [0.11, 0.18, 0.27, 0.34, 0.13, 0.23, 0.31]
    py = [0.30, 0.39, 0.31, 0.47, 0.56, 0.53, 0.62]
    scatter!(ax, px, py; color=GREEN, markersize=13)
    scatter!(ax, [0.52, 0.62, 0.73, 0.84], [0.32, 0.45, 0.37, 0.56];
        color=BLUE, markersize=13)
    arrows2d!(ax, [Point2f(0.31, 0.50)], [Vec2f(0.25, -0.02)];
        color=GREEN, shaftwidth=4, tipwidth=20, tiplength=22)
    text!(ax, 0.47, 0.55; text="spillover m", color=GREEN,
        fontsize=23, font=:bold, align=(:center, :bottom))
    text!(ax, 0.50, 0.08; text="accessible share = 1 − fₚ",
        color=RED, fontsize=24, font=:bold, align=(:center, :bottom))
end

function protected_math_panel!(layout)
    ax = hidden_axis(layout; title="Access and ecology\nchange together")
    text!(ax, 0.04, 0.84;
        text=L"\theta_i^{\mathrm{PA}}=\frac{\theta_i}{1-f_p}",
        color=RED, fontsize=34, align=(:left, :center))
    text!(ax, 0.04, 0.64;
        text=L"\sum_i u_i=1-y+h(y)",
        color=GREEN, fontsize=34, align=(:left, :center))
    text!(ax, 0.04, 0.46;
        text=L"\bar{u}_i^{\mathrm{PA}}(y)=\frac{1-y}{1-y+h(y)}\bar{u}_i",
        color=BLUE, fontsize=30, align=(:left, :center))
    text!(ax, 0.04, 0.27;
        text="Less accessible habitat raises the stock\nneeded for harvesting to pay. Spillover adds\nrenewal, so the same physical use creates\nless net pressure.",
        color=MUTED, fontsize=23, align=(:left, :top))
end

function protected_figure(data)
    fig = figure_shell(
        "Protected areas: less access is partly offset by ecological spillover",
        "Protection changes both sides of the balance: actors need more resource density to harvest,\nwhile biomass moving out of the protected patch supports renewal.",
        "Protection can raise the attractor through two mechanisms at once:\nan access-induced threshold shift and a spillover-induced reduction in net pressure.")
    protected_rule_panel!(fig[4, 1])
    protected_math_panel!(fig[4, 2])
    phase_panel!(fig[6, 1], data.oa, [data.protected];
        colors=[GREEN], names=["protected area"])
    outcome_panel!(fig[6, 2], [data.oa, data.protected],
        ["open access", "protected area"], [GRAY, GREEN])
    save_pair(fig, "figureS5_protected_policy_explainer")
    return fig
end

function economic_rule_panel!(layout)
    ax = hidden_axis(layout; title="Two levers act through\ndifferent channels")
    text!(ax, 0.08, 0.78; text="ROYALTY", color=BLUE,
        fontsize=25, font=:bold, align=(:left, :center))
    text!(ax, 0.08, 0.64; text="actor keeps only p(1−ρ)", color=DARK,
        fontsize=24, align=(:left, :center))
    arrows2d!(ax, [Point2f(0.72, 0.72)], [Vec2f(0.0, -0.18)];
        color=RED, shaftwidth=4, tipwidth=20, tiplength=22)
    text!(ax, 0.78, 0.63; text="return ↓", color=RED,
        fontsize=23, font=:bold, align=(:left, :center))

    text!(ax, 0.08, 0.38; text="GEAR SUPPORT", color=ORANGE,
        fontsize=25, font=:bold, align=(:left, :center))
    text!(ax, 0.08, 0.24; text="catchability rises to q* = gq", color=DARK,
        fontsize=24, align=(:left, :center))
    arrows2d!(ax, [Point2f(0.72, 0.21)], [Vec2f(0.0, 0.18)];
        color=GREEN, shaftwidth=4, tipwidth=20, tiplength=22)
    text!(ax, 0.78, 0.31; text="capacity ↑", color=GREEN,
        fontsize=23, font=:bold, align=(:left, :center))
end

function economic_math_panel!(layout, ρ, g)
    ax = hidden_axis(layout; title="Each lever has a distinct\nmathematical effect")
    text!(ax, 0.04, 0.87; text="ROYALTY", color=BLUE,
        fontsize=22, font=:bold, align=(:left, :center))
    text!(ax, 0.04, 0.76;
        text=L"\theta_i^{\rho}=\frac{\theta_i}{1-\rho}",
        color=BLUE, fontsize=29, align=(:left, :center))
    text!(ax, 0.52, 0.76; text=L"\bar{u}_i^{\rho}=\bar{u}_i",
        color=BLUE, fontsize=29, align=(:left, :center))
    text!(ax, 0.04, 0.61; text="GEAR SUPPORT", color=ORANGE,
        fontsize=22, font=:bold, align=(:left, :center))
    text!(ax, 0.04, 0.50;
        text=L"\theta_i^{s}=\frac{\theta_i}{g}",
        color=ORANGE, fontsize=29, align=(:left, :center))
    text!(ax, 0.52, 0.50; text=L"\bar{u}_i^{s}=g\bar{u}_i",
        color=ORANGE, fontsize=29, align=(:left, :center))
    text!(ax, 0.04, 0.36;
        text=@sprintf("Illustration:  royalty rate = %.2f and g = %.2f", ρ, g),
        color=DARK, fontsize=24, font=:bold, align=(:left, :center))
    text!(ax, 0.04, 0.24;
        text="A royalty raises exit thresholds without\nchanging physical capacity. Better gear\nboth lowers thresholds and raises impact\npotential.",
        color=MUTED, fontsize=23, align=(:left, :top))
end

function economic_figure(data)
    fig = figure_shell(
        "Economic instruments: price and technology enter through different relational variables",
        "A royalty reduces retained harvesting returns; gear support raises catchability. Their effects cannot be represented by one generic policy shift.",
        "Royalty makes exit more attractive and raises resource density;\ngear support makes harvesting attractive at lower stocks while increasing potential pressure.")
    economic_rule_panel!(fig[4, 1])
    economic_math_panel!(fig[4, 2], data.royalty_rate, data.gear_factor)
    phase_panel!(fig[6, 1], data.oa, [data.royalty, data.gear];
        colors=[BLUE, ORANGE], names=["royalty", "gear support"])
    outcome_panel!(fig[6, 2], [data.oa, data.royalty, data.gear],
        ["open access", "royalty", "gear support"], [GRAY, BLUE, ORANGE])
    save_pair(fig, "figureS6_economic_policy_explainer")
    return fig
end

function generate_policy_explainers()
    data = build_policy_solutions()
    figures = (
        exclusive_figure(data),
        tradable_figure(data),
        protected_figure(data),
        economic_figure(data),
    )
    return figures
end

end # module

if abspath(PROGRAM_FILE) == @__FILE__
    PolicyExplainers.generate_policy_explainers()
    println("Wrote four policy explainer figures to SupplementaryMaterial/figures")
end
