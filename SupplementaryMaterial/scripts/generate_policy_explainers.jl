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
        fontsize=30,
        font="Arial",
        Axis=(
            backgroundcolor=:white,
            xgridcolor=GRID,
            ygridcolor=GRID,
            spinewidth=1.0,
            xticklabelsize=25,
            yticklabelsize=25,
            xlabelsize=29,
            ylabelsize=29,
            titlesize=30,
            titlefont=:bold,
        ),
    )
end

function hidden_axis(layout; title="")
    ax = Axis(layout)
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
        income_cost_fun=(x, p, t) -> thresholds,
        resource_factor_fun=(x, p, t) -> 1 - royalty_rate,
        income_state_fun=(x, p, t) -> royalty_rate .* x[1:p.N] .* x[p.N+1],
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
        u0=gear_factor .* oa_state[1:base_s.N], y0=oa_state[base_s.N + 1], t_end=1600.0)

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
        Figure(size=(1650, 1450), backgroundcolor=:white)
    end
    Label(fig[1, 1:2], title; fontsize=40, font=:bold, color=DARK,
        tellwidth=false, padding=(0, 0, 8, 18))
    Label(fig[2, 1:2], subtitle; fontsize=27, color=MUTED,
        tellwidth=false, padding=(0, 0, 6, 0))
    for (j, label) in enumerate(("A  The institutional rule", "B  Actor incentives"))
        Label(fig[3, j], label; fontsize=27, font=:bold, color=DARK,
            tellwidth=false, halign=:left, padding=(4, 0, 6, 0))
    end
    for (j, label) in enumerate(("C  Participation balance", "D  Long-run outcomes"))
        Label(fig[5, j], label; fontsize=27, font=:bold, color=DARK,
            tellwidth=false, halign=:left, padding=(4, 0, 6, 0))
    end
    Label(fig[7, 1:2], takeaway; fontsize=27,
        color=DARK, tellwidth=false, halign=:left, padding=(4, 0, 20, 0))
    rowsize!(fig.layout, 4, Auto(1.0))
    rowsize!(fig.layout, 6, Auto(1.1))
    colgap!(fig.layout, 55)
    rowgap!(fig.layout, 10)
    return fig
end

function scenario_key!(ax, entries; x=0.04, y=0.95, gap=0.075)
    for (j, (name, color)) in enumerate(entries)
        yy = y - (j - 1) * gap
        lines!(ax, [x, x + 0.08], [yy, yy]; color, linewidth=5)
        text!(ax, x + 0.10, yy; text=name, color, fontsize=25,
            font=:bold, align=(:left, :center))
    end
end

function phase_panel!(layout, oa, variants;
        colors, names, title="")
    grid = GridLayout(layout)
    ax = Axis(grid[2, 1]; title,
        xlabel="resource level, y",
        ylabel="Participation (share of all actors)",
        xticks=0:0.5:1, yticks=0:0.5:1)
    xlims!(ax, 0, 1)
    ylims!(ax, 0, 1)

    y0, p0, i0 = curve_data(oa)
    lines!(ax, y0, p0; color=withalpha(GRAY, 0.92), linewidth=6)
    lines!(ax, y0, i0; color=withalpha(GRAY, 0.92), linewidth=5,
        linestyle=:dash)
    ystar0, pstar0 = attractor(oa)
    scatter!(ax, [ystar0], [pstar0]; color=GRAY, markersize=26,
        strokecolor=:white, strokewidth=1.2)

    for (j, sol) in enumerate(variants)
        y, pcurve, icurve = curve_data(sol)
        lines!(ax, y, pcurve; color=colors[j], linewidth=4)
        lines!(ax, y, icurve; color=colors[j], linewidth=3, linestyle=:dash)
        ystar, pstar = attractor(sol)
        scatter!(ax, [ystar], [pstar]; color=colors[j], markersize=22,
            strokecolor=:white, strokewidth=1.4)
        if length(variants) > 1
            text!(ax, ystar + 0.018, pstar + 0.025;
                text=string(j), color=colors[j], fontsize=25, font=:bold,
                align=(:left, :bottom))
        end
    end

    names_with_tags = [length(variants) > 1 ? "$(j)  $(names[j])" : names[j]
        for j in eachindex(names)]
    Legend(grid[1, 1], [LineElement(color=GRAY, linewidth=4);
            [LineElement(color=c, linewidth=4) for c in colors]],
        ["Open access"; names_with_tags];
        orientation=:horizontal, nbanks=length(variants) > 1 ? 2 : 1,
        framevisible=false, labelsize=24, tellwidth=false)
    Legend(grid[3, 1],
        [LineElement(color=DARK, linewidth=3),
            LineElement(color=DARK, linewidth=3, linestyle=:dash)],
        ["Participation", "Required participation"];
        orientation=:horizontal, framevisible=false, labelsize=23,
        tellwidth=false)
    rowgap!(grid, 8)
    return ax
end

function outcome_panel!(layout, solutions, names, colors;
        title="")
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
                fontsize=25, font=:bold, align=(:left, :center))
        end
    end
    axislegend(ax; position=:rt, framevisible=false, labelsize=23,
        patchsize=(20, 14), rowgap=4)
    return ax
end

function actor_row!(ax, y, excluded; label, color)
    n = length(excluded)
    xs = collect(range(0.08, 0.92; length=n))
    scatter!(ax, xs, fill(y, n); color=fill(withalpha(color, 0.88), n),
        markersize=28)
    for i in findall(excluded)
        scatter!(ax, [xs[i]], [y]; marker=:xcross, color=RED,
            markersize=31, strokewidth=4)
    end
    text!(ax, 0.04, y + 0.105; text=label, color, fontsize=26,
        font=:bold, align=(:left, :center))
end

function exclusive_rule_panel!(layout)
    ax = hidden_axis(layout; title="Who receives an enforceable right?")
    actor_row!(ax, 0.70, [falses(8); trues(4)];
        label="1  exclude high-threshold actors", color=BLUE)
    actor_row!(ax, 0.34, [trues(4); falses(8)];
        label="2  exclude low-threshold actors", color=ORANGE)
    text!(ax, 0.08, 0.13; text="low θ", color=MUTED,
        fontsize=25, align=(:left, :center))
    text!(ax, 0.92, 0.13; text="high θ", color=MUTED,
        fontsize=25, align=(:right, :center))
    arrows2d!(ax, [Point2f(0.08, 0.06)], [Vec2f(0.84, 0.0)];
        color=MUTED, shaftwidth=2.5, tipwidth=13, tiplength=15)
end

function exclusive_math_panel!(layout)
    ax = hidden_axis(layout; title="Unauthorized use triggers a sanction")
    text!(ax, 0.04, 0.82;
        text=L"v_i^{\mathrm{EUR}}=v_i^{\mathrm{OA}}-S\max(0,u_i-R_i)",
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
        text="For S ≥ 1, unauthorized use has\nno positive return. Only the excess\nabove Rᵢ is sanctioned.",
        color=MUTED, fontsize=26, align=(:left, :top))
end

function exclusive_figure(data)
    fig = figure_shell(
        "Exclusive use rights",
        "Strong sanctions prevent unauthorized use. Which actors retain access determines the outcome.",
        "The same excluded share can give different outcomes:\nremoving persistent users changes pressure more than removing actors who would already exit.")
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
        color=BLUE, fontsize=26, font=:bold, align=(:left, :center))
    text!(ax, 0.04, 0.55; text="historical rights: prior users share Q",
        color=ORANGE, fontsize=26, font=:bold, align=(:left, :center))
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
        text="Use above Rᵢ is bought; unused Rᵢ is sold.\nExcess total use raises the common price.\nThe price cannot fall below zero.",
        color=MUTED, fontsize=26, align=(:left, :top))
end

function transfer_axis!(layout, sol, title, thresholds; show_xlabel=false, shared_limit=nothing)
    p = sol.prob.p
    x = steady_state(sol)
    transfer = incomes(x, p).trade
    order = sortperm(thresholds)
    transfer = transfer[order]
    n = length(transfer)
    lim = isnothing(shared_limit) ? 1.15 * maximum(abs, transfer) : shared_limit
    ax = Axis(layout; title, ylabel="rights transfer",
        xlabel=show_xlabel ? "actors ordered by exit threshold" : "")
    barplot!(ax, 1:n, transfer;
        color=[v >= 0 ? GREEN : RED for v in transfer], width=0.86)
    hlines!(ax, [0]; color=DARK, linewidth=1.2)
    xlims!(ax, 0.5, n + 0.5)
    ylims!(ax, -lim, lim)
    ax.xticksvisible = false
    ax.xticklabelsvisible = false
    text!(ax, 0.98n, 0.88lim; text="receives +", color=GREEN,
        fontsize=26, font=:bold, align=(:right, :top))
    text!(ax, 0.98n, -0.88lim; text="pays −", color=RED,
        fontsize=26, font=:bold, align=(:right, :bottom))
    text!(ax, 0.03, 0.94; text=@sprintf("Total-income Gini %.2f", incomes(x, p).gini),
        space=:relative, color=DARK, fontsize=24, align=(:left, :top))
    return ax
end

function tradable_figure(data)
    fig = figure_shell(
        "Tradable use rights",
        "The quota controls total use; the initial allocation determines who receives scarcity rent.",
        "At market clearing, payments by buyers equal receipts by sellers.\nDifferent initial rights can redistribute income without changing final use or resource density.")
    tradable_rule_panel!(fig[4, 1])
    tradable_math_panel!(fig[4, 2])
    phase = phase_panel!(fig[6, 1], data.oa, [data.tradable_equal];
        colors=[ORANGE], names=["equal and historical rights"])
    price = steady_state(data.tradable_equal)[end]
    median_before = median(data.thresholds)
    arrows2d!(phase, [Point2f(median_before, 0.50)], [Vec2f(price, 0.0)];
        color=RED, shaftwidth=3, tipwidth=16, tiplength=18)
    text!(phase, median_before + price / 2, 0.55;
        text=@sprintf("price ϕ = %.2f", price), color=RED, fontsize=25,
        align=(:center, :bottom))

    rent_grid = GridLayout(fig[6, 2])
    transfers = [incomes(steady_state(sol), sol.prob.p).trade
        for sol in (data.tradable_equal, data.tradable_historical)]
    common_limit = 1.15 * maximum(maximum(abs, values) for values in transfers)
    top = transfer_axis!(rent_grid[1, 1], data.tradable_equal,
        "Equal initial rights", data.thresholds; shared_limit=common_limit)
    bottom = transfer_axis!(rent_grid[2, 1], data.tradable_historical,
        "Historical initial rights", data.thresholds;
        show_xlabel=true, shared_limit=common_limit)
    linkyaxes!(top, bottom)
    rowgap!(rent_grid, 6)
    y_equal, p_equal = attractor(data.tradable_equal)
    Label(rent_grid[0, 1], @sprintf("Both:  y* = %.2f, participation = %.2f",
        y_equal, p_equal); fontsize=25, font=:bold, color=DARK, tellwidth=false)
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
        fontsize=26, font=:bold, align=(:center, :bottom))
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
        color=MUTED, fontsize=26, align=(:left, :top))
end

function protected_figure(data)
    fig = figure_shell(
        "Protected areas",
        "Reduced access discourages harvesting; biomass spillover adds renewal in the exploited area.",
        "Access shifts participation to the right; spillover raises sustainable participation.\nThe reduction matches the two-patch equilibrium, not its full transient dynamics.")
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
        fontsize=26, font=:bold, align=(:left, :center))

    text!(ax, 0.08, 0.38; text="GEAR SUPPORT", color=ORANGE,
        fontsize=25, font=:bold, align=(:left, :center))
    text!(ax, 0.08, 0.24; text="catchability rises to q* = gq", color=DARK,
        fontsize=24, align=(:left, :center))
    arrows2d!(ax, [Point2f(0.72, 0.21)], [Vec2f(0.0, 0.18)];
        color=GREEN, shaftwidth=4, tipwidth=20, tiplength=22)
    text!(ax, 0.78, 0.31; text="efficiency ↑", color=GREEN,
        fontsize=26, font=:bold, align=(:left, :center))
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
        text="A royalty raises exit thresholds without\nchanging impact potential. Better gear\nboth lowers thresholds and raises impact\npotential.",
        color=MUTED, fontsize=26, align=(:left, :top))
end

function economic_figure(data)
    fig = figure_shell(
        "Royalties and gear support",
        "A royalty changes retained price. Better gear changes both exit thresholds and impact potentials.",
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
    figures = with_theme(explainer_theme()) do
        (exclusive_figure(data), tradable_figure(data),
            protected_figure(data), economic_figure(data))
    end
    return figures
end

end # module

if abspath(PROGRAM_FILE) == @__FILE__
    PolicyExplainers.generate_policy_explainers()
    println("Wrote four policy explainer figures to SupplementaryMaterial/figures")
end
