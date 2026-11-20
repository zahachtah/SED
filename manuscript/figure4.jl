#!/usr/bin/env julia

include(joinpath(@__DIR__, "helpers", "policy_scenarios.jl"))
include(joinpath(@__DIR__, "helpers", "figure_style.jl"))

using CairoMakie
using LaTeXStrings
using Printf

const SCEN_BLUE = RGBf(0.10, 0.34, 0.78)
const SCEN_ORANGE = RGBf(0.92, 0.43, 0.10)
const SCEN_TEAL = RGBf(0.06, 0.53, 0.55)
const SCEN_PURPLE = RGBf(0.46, 0.34, 0.78)
const RENT_RED = RGBf(0.82, 0.12, 0.13)
const SPILLOVER_GREEN = RGBf(0.16, 0.55, 0.24)

mix_rgb(a, b, t) = RGBf((1 - t) * a.r + t * b.r,
    (1 - t) * a.g + t * b.g,
    (1 - t) * a.b + t * b.b)

dimmed_equation_color() = withalpha(mix_rgb(GRAY, DARK, 0.28), 0.94)

math_lhs_size(figstyle) = pt(figstyle, 19.0)
math_term_size(figstyle) = pt(figstyle, 17.2)
math_subterm_size(figstyle) = pt(figstyle, 16.0)

scenario_label(label) = replace(label,
    "High w̃ exclusion" => "High θᵢ excluded",
    "Low w̃ exclusion" => "Low θᵢ excluded",
    "High Tᵢ exclusion" => "High θᵢ excluded",
    "Low Tᵢ exclusion" => "Low θᵢ excluded",
    "Equal effort rights" => "Equal use rights",
    "Historical effort rights" => "Historical use rights",
    "Protected area only" => "Protected area",
    "Protected area + tourism" => "Protected area + tourism effect",
    "Low mobility, 30% protected" => "Low mobility",
    "High mobility, 10% protected" => "High mobility")

phase_scenario_label(label) = replace(scenario_label(label),
    "Equal effort quota" => "Equal use rights",
    "Historical effort quota" => "Historical use rights")

function baseline_thresholds_for(p, x, t)
    if hasproperty(p, :w̃)
        return hasproperty(p.w̃, :data) ? p.w̃.data : p.w̃
    end
    return p.cost(x, p, t)
end

function wrap_words(text; width=31)
    words = split(replace(text, "\n" => " "))
    lines = String[]
    line = ""
    for word in words
        candidate = isempty(line) ? String(word) : string(line, " ", word)
        if length(candidate) > width && !isempty(line)
            push!(lines, line)
            line = String(word)
        else
            line = candidate
        end
    end
    isempty(line) || push!(lines, line)
    return join(lines, "\n")
end

function option_colors(style, j, variant)
    if style == :fixed_hues
        return j == 1 ? SCEN_BLUE : SCEN_ORANGE
    elseif style == :badges
        return j == 1 ? variant.color : mix_rgb(variant.color, DARK, 0.22)
    else
        return j == 1 ? SCEN_TEAL : SCEN_PURPLE
    end
end

function option_marker(style, j)
    style == :badges && return j == 1 ? :circle : :diamond
    return :circle
end

function option_line(style, j)
    style == :badges && return j == 1 ? nothing : :dash
    return nothing
end

function x_at_curve_level(xs, ys, level)
    for i in 2:length(xs)
        lo = ys[i-1]
        hi = ys[i]
        all(isfinite, (xs[i-1], xs[i], lo, hi)) || continue
        if (lo <= level <= hi) || (hi <= level <= lo)
            denom = hi - lo
            abs(denom) < eps() && return 0.5 * (xs[i-1] + xs[i])
            t = (level - lo) / denom
            return xs[i-1] + t * (xs[i] - xs[i-1])
        end
    end
    finite = findall(i -> isfinite(xs[i]) && isfinite(ys[i]), eachindex(xs))
    isempty(finite) && error("curve contains no finite points")
    return xs[finite[argmin(abs.(ys[finite] .- level))]]
end

function curve_point(xs, ys, x)
    i = clamp(searchsortedlast(xs, x), 1, length(xs) - 1)
    finite_segments = findall(j ->
        all(isfinite, (xs[j], xs[j+1], ys[j], ys[j+1])),
        1:(length(xs) - 1))
    isempty(finite_segments) && error("curve contains no finite segment")
    if !(i in finite_segments)
        i = finite_segments[argmin(abs.(
            0.5 .* (xs[finite_segments] .+ xs[finite_segments .+ 1]) .- x))]
    end
    x0, x1 = xs[i], xs[i+1]
    y0, y1 = ys[i], ys[i+1]
    denom = max(x1 - x0, eps())
    x_eval = clamp(x, x0, x1)
    t = clamp((x_eval - x0) / denom, 0.0, 1.0)
    return Point2f(x_eval, y0 + t * (y1 - y0))
end

function draw_curve_transfer_arrow!(ax, xs0, ys0, xs1, ys1, x_start, x_stop, color;
        bend=0.0, linewidth=1.6, figstyle=paper_figure_style())
    start = curve_point(xs0, ys0, x_start)
    stop = curve_point(xs1, ys1, x_stop)
    start == stop && throw(ArgumentError("policy arrow endpoints coincide"))
    width = pt(figstyle, linewidth)
    path = iszero(bend) ? Makie.Ann.Paths.Line() : Makie.Ann.Paths.Arc(height=bend)
    return annotation!(ax, start[1], start[2], stop[1], stop[2];
        text="", labelspace=:data, shrink=(0, 0), path,
        style=Makie.Ann.Styles.LineArrow(head=Makie.Ann.Arrows.Head(length=4width)),
        color, linewidth=width)
end

function draw_number_badge!(ax, x, y, j, color, figstyle; marker=:circle)
    scatter!(ax, [x], [y]; marker, color, markersize=pt(figstyle, 20),
        strokecolor=:white, strokewidth=1.0)
    text!(ax, x, y; text=string(j), align=(:center, :center),
        color=:white, font=:bold, fontsize=pt(figstyle, 9.2))
end

function draw_split_badge!(ax, x, y, colors, figstyle)
    rx = 0.027
    ry = 0.038
    center = Point2f(x, y)
    left_arc = Point2f[Point2f(x + rx * cos(θ), y + ry * sin(θ)) for θ in range(π / 2, 3π / 2, length=38)]
    right_arc = Point2f[Point2f(x + rx * cos(θ), y + ry * sin(θ)) for θ in range(-π / 2, π / 2, length=38)]
    left_poly = vcat(Point2f[center], left_arc)
    right_poly = vcat(Point2f[center], right_arc)
    poly!(ax, left_poly; color=colors[1],
        strokecolor=:white, strokewidth=0.9)
    poly!(ax, right_poly; color=colors[2],
        strokecolor=:white, strokewidth=0.9)
    lines!(ax, [x, x], [y - ry, y + ry]; color=:white, linewidth=0.9)
    text!(ax, x - 0.009, y; text="1", align=(:center, :center),
        color=:white, font=:bold, fontsize=pt(figstyle, 9.1))
    text!(ax, x + 0.009, y; text="2", align=(:center, :center),
        color=:white, font=:bold, fontsize=pt(figstyle, 9.1))
end

function policy_value_rows(row)
    row.title == "Exclusive use rights" && return [
        (L"u_i y", false),
        (L"+(\bar{u}_i-u_i)\theta_i", false),
        (L"-S\max(0,u_i-R_i)", true),
    ]
    row.title == "Tradable use rights" && return [
        (L"u_i y", false),
        (L"+(\bar{u}_i-u_i)\theta_i", false),
        (L"+(R_i-u_i)\phi", true),
        (L"\dot{\phi}=D-S", true),
    ]
    row.title == "Protected areas" && return [
        (L"u_i(1-f_p)y", true),
        (L"+(\bar{u}_i-u_i)\theta_i", false),
        (L"\bar{u}_i^{\mathrm{PA}}=\bar{u}_i\frac{1-y}{1-y+h(y)}", true),
        (L"\theta_i^{\mathrm{PA+tourism}}=1.2\theta_i^{\mathrm{PA}}", true),
    ]
    row.title == "Economic policy outcomes" && return [
        (L"(1-\rho)u_i y", true),
        (L"+(g\bar{u}_i-u_i)\theta_i/g", true),
        (L"\theta_i^{*}=\theta_i/[g(1-\rho)]", true),
        (L"\bar{u}_i^{*}=g\bar{u}_i", true),
    ]
    return [(L"v_i", true)]
end

function draw_value_function!(ax, row, figstyle)
    rows = policy_value_rows(row)
    y_start = 0.515
    line_gap = 0.104
    text!(ax, 0.10, y_start; text=L"v_i=",
        color=withalpha(DARK, 0.96), fontsize=math_lhs_size(figstyle),
        align=(:left, :top))

    if row.title == "Protected areas"
        y1 = y_start
        text!(ax, 0.275, y1; text=L"u_i",
            color=withalpha(DARK, 0.98), fontsize=math_term_size(figstyle),
            align=(:left, :top))
        text!(ax, 0.350, y1; text=L"(1-f_p)y",
            color=withalpha(RENT_RED, 0.98), fontsize=math_term_size(figstyle),
            align=(:left, :top))
        protected_rows = [
            (L"+(\bar{u}_i-u_i)\theta_i", withalpha(DARK, 0.98), 0.405, math_term_size(figstyle)),
            (L"\bar{u}_i^{\mathrm{PA}}=\bar{u}_i\frac{1-y}{1-y+h(y)}", withalpha(SPILLOVER_GREEN, 0.98), 0.265, math_subterm_size(figstyle)),
            (L"\theta_i^{\mathrm{PA+tourism}}=1.2\theta_i^{\mathrm{PA}}", withalpha(SCEN_ORANGE, 0.98), 0.100, math_subterm_size(figstyle)),
        ]
        for (equation, color, y, fontsize) in protected_rows
            text!(ax, 0.275, y; text=equation,
                color, fontsize, align=(:left, :top))
        end
        return nothing
    end

    if row.title == "Economic policy outcomes"
        text!(ax, 0.275, y_start; text=L"(1-\rho)u_i y",
            color=withalpha(RENT_RED, 0.98), fontsize=math_term_size(figstyle),
            align=(:left, :top))
        term_y = y_start - line_gap
        text!(ax, 0.275, term_y; text=L"+(g\bar{u}_i-u_i)\theta_i/g",
            color=withalpha(DARK, 0.98), fontsize=math_term_size(figstyle),
            align=(:left, :top))
        economic_rows = [
            (L"\theta_i^{*}=\theta_i/[g(1-\rho)]", withalpha(RENT_RED, 0.98)),
            (L"\bar{u}_i^{*}=g\bar{u}_i", withalpha(SPILLOVER_GREEN, 0.98)),
        ]
        for (j, (equation, color)) in enumerate(economic_rows)
            text!(ax, 0.275, y_start - (j + 1) * line_gap; text=equation,
                color, fontsize=math_subterm_size(figstyle), align=(:left, :top))
        end
        return nothing
    end

    for (k, (equation, changed)) in enumerate(rows)
        y = y_start - (k - 1) * line_gap
        term_color = row.title == "Tradable use rights" && k == 3 ?
            withalpha(RENT_RED, 0.98) :
            row.title == "Exclusive use rights" && k == 3 ?
            withalpha(RENT_RED, 0.98) :
            (changed ? withalpha(DARK, 0.98) : dimmed_equation_color())
        text!(ax, 0.275, y; text=equation,
            color=term_color, fontsize=math_term_size(figstyle),
            align=(:left, :top))
    end
end

function draw_exclusive_exclusion_segment!(ax, sol, figstyle)
    p = sol.prob.p
    hasproperty(p, :policy) && p.policy isa ExclusiveUseRights || return nothing
    hasproperty(p, :R) || return nothing

    x = steady_state(sol)
    thresholds = baseline_thresholds_for(p, x, steady_time(sol))
    excluded = p.R .> 0.5
    kept = .!excluded
    any(excluded) && any(kept) || return nothing

    cap = count(kept) / p.N
    excluded_thresholds = thresholds[excluded]
    kept_thresholds = thresholds[kept]
    red = withalpha(RENT_RED, 0.96)
    line_width = pt(figstyle, 3.05)
    dot_size = pt(figstyle, 8.2)

    if median(excluded_thresholds) > median(kept_thresholds)
        x0 = clamp(minimum(excluded_thresholds), 0.0, 1.0)
        lines!(ax, [x0, 1.0], [cap, cap]; color=red, linewidth=line_width)
        scatter!(ax, [x0], [cap]; color=red, markersize=dot_size,
            strokecolor=:white, strokewidth=0.65)
    else
        x1 = clamp(maximum(excluded_thresholds), 0.0, 1.0)
        y0 = 0.012
        lines!(ax, [0.0, x1], [y0, y0]; color=red, linewidth=line_width)
        scatter!(ax, [x1], [y0]; color=red, markersize=dot_size,
            strokecolor=:white, strokewidth=0.65)
    end
    return nothing
end

function draw_policy_info_panel!(ax, row, figstyle)
    hidespines!(ax)
    hidedecorations!(ax)
    xlims!(ax, 0, 1)
    ylims!(ax, 0, 1)

    poly!(ax, Rect2f(0.0, 0.0, 1.0, 1.0);
        color=RGBAf(0.12, 0.16, 0.20, 0.035), strokewidth=0)
    title_text = wrap_words(row.title; width=22)
    title_lines = count(==('\n'), title_text) + 1
    description_y = 0.83 - 0.075 * (title_lines - 1)
    text!(ax, 0.06, 0.93; text=title_text,
        color=DARK, fontsize=pt(figstyle, 14.4),
        font=:bold, align=(:left, :top))
    text!(ax, 0.06, description_y; text=wrap_words(row.note; width=44),
        color=withalpha(MUTED, 0.96), fontsize=pt(figstyle, 11.7),
        align=(:left, :top), justification=:left)

    poly!(ax, Rect2f(0.055, 0.025, 0.89, 0.54);
        color=:white, strokecolor=RGBAf(0.12, 0.16, 0.20, 0.14),
        strokewidth=0.8)
    draw_value_function!(ax, row, figstyle)
    return ax
end

function draw_phase_pairing!(ax, row, oa_sol, style, figstyle; show_xlabel=true)
    style_compact_phase!(ax)
    ax.xlabelvisible = show_xlabel
    ax.xlabelsize = pt(figstyle, 13.4)
    ax.xlabelfont = :bold
    ax.ylabelsize = pt(figstyle, 12)
    ax.xticklabelsize = pt(figstyle, 10)
    ax.yticklabelsize = pt(figstyle, 10)
    poly!(ax, Rect2f(0, 0, 0.5, 1); color=SHADE, strokewidth=0)

    y0, Γ0, Φ0 = curves_for(oa_sol)
    yo, po = attractor(oa_sol)
    lines!(ax, y0, Γ0; color=withalpha(GRAY, 0.58), linewidth=3.3)
    lines!(ax, y0, Φ0; color=withalpha(GRAY, 0.42), linewidth=2.3, linestyle=:dash)
    scatter!(ax, [yo], [po]; color=withalpha(GRAY, 0.92), markersize=pt(figstyle, 11),
        strokecolor=:white, strokewidth=0.9)

    is_tradable_row = row.title == "Tradable use rights"
    is_protected_row = row.title == "Protected areas"
    is_exclusive_row = row.title == "Exclusive use rights"
    is_economic_row = row.title == "Economic policy outcomes"
    attractor_points = Point2f[]
    attractor_colors = Any[]
    variant_curves = []
    scenario_badges = []
    for (j, v) in enumerate(row.variants)
        color = option_colors(style, j, v)
        y, Γ, Φ = curves_for(v.sol)
        yp, pp = attractor(v.sol)
        linestyle = option_line(style, j)
        marker = option_marker(style, j)
        alpha = style == :badges ? 1.0 : (j == 1 ? 0.98 : 0.88)

        line_kwargs = isnothing(linestyle) ? NamedTuple() : (; linestyle)
        lines!(ax, y, Γ; color=withalpha(color, alpha), linewidth=3.65, line_kwargs...)
        lines!(ax, y, Φ; color=withalpha(color, alpha * 0.82), linewidth=2.35, linestyle=:dash)
        is_exclusive_row && draw_exclusive_exclusion_segment!(ax, v.sol, figstyle)
        push!(variant_curves, (; y, Γ, Φ, color, label=v.label))
        push!(attractor_points, Point2f(yp, pp))
        push!(attractor_colors, withalpha(color, alpha))
        push!(scenario_badges, (; x=yp, y=pp, j, color=withalpha(color, alpha), marker))
        if !is_tradable_row && !(is_protected_row || is_economic_row)
            draw_number_badge!(ax, yp, pp, j, withalpha(color, alpha), figstyle; marker)
        end

        label_text = phase_scenario_label(v.label)
        xtext = clamp(yp + 0.036, 0.05, 0.78)
        ytext = clamp(pp + 0.044 - 0.075 * (j - 1), 0.08, 0.92)
        label_align = (:left, :center)
        if length(label_text) > 18 && xtext > 0.40
            xtext = 0.96
            label_align = (:right, :center)
        end
        if is_protected_row && j == 2
            label_text = replace(label_text, " + " => "\n+ ")
            xtext = clamp(yp + 0.060, 0.05, 0.78)
            ytext = clamp(pp - 0.006, 0.08, 0.92)
            label_align = (:left, :center)
        end
        if is_economic_row && j == 2
            xtext, ytext = 0.96, 0.96
            label_align = (:right, :top)
        end
        if style == :cards
            text!(ax, xtext, ytext; text=label_text,
                color=withalpha(color, 0.98), fontsize=pt(figstyle, 10.8), font=:bold,
                align=label_align)
        else
            text!(ax, xtext, ytext; text=label_text,
                color=withalpha(color, 0.98), fontsize=pt(figstyle, 10.8), font=:bold,
            align=label_align)
        end
    end

    if is_tradable_row && length(attractor_points) == 2
        p1, p2 = attractor_points
        draw_split_badge!(ax, 0.5 * (p1[1] + p2[1]), 0.5 * (p1[2] + p2[2]),
            attractor_colors, figstyle)
    end

    if is_economic_row
        lines!(ax, y0, Γ0; color=withalpha(GRAY, 0.76), linewidth=4.0)
        lines!(ax, y0, Φ0; color=withalpha(GRAY, 0.60), linewidth=2.9, linestyle=:dash)
        scatter!(ax, [yo], [po]; color=withalpha(GRAY, 0.96), markersize=pt(figstyle, 13),
            strokecolor=:white, strokewidth=1.0)
        text!(ax, 0.69, 0.86;
            text="open access", color=withalpha(GRAY, 0.98),
            fontsize=pt(figstyle, 10.4), font=:bold, align=(:left, :center))
    end

    if is_tradable_row && !isempty(row.variants)
        y_policy, Γ_policy, _ = curves_for(row.variants[1].sol)
        x_open = x_at_curve_level(y0, Γ0, 0.5)
        x_policy = x_at_curve_level(y_policy, Γ_policy, 0.5)
        if x_policy > x_open + 0.015
            arrow_y = 0.54
            arrow_color = withalpha(RENT_RED, 0.95)
            width = pt(figstyle, 1.6)
            annotation!(ax, x_open, arrow_y, x_policy, arrow_y;
                text="", labelspace=:data, shrink=(0, 0),
                style=Makie.Ann.Styles.LineArrow(head=Makie.Ann.Arrows.Head(length=4width)),
                color=arrow_color, linewidth=width)
            text!(ax, 0.5 * (x_open + x_policy), arrow_y + 0.045;
                text="ϕ", color=arrow_color, fontsize=pt(figstyle, 15.6),
                font=:bold, align=(:center, :bottom))
        end
    end

    if is_protected_row && !isempty(variant_curves)
        v1 = variant_curves[1]
        spill_color = withalpha(SPILLOVER_GREEN, 0.94)
        access_color = withalpha(RENT_RED, 0.90)
        draw_curve_transfer_arrow!(ax, y0, Φ0, v1.y, v1.Φ,
            0.065, 0.325, spill_color; bend=0.38, figstyle)
        text!(ax, 0.04, 0.86;
            text="spillover\neffect", color=spill_color,
            fontsize=pt(figstyle, 11.4), font=:bold, align=(:left, :center))

        draw_curve_transfer_arrow!(ax, y0, Γ0, v1.y, v1.Γ,
            0.355, 0.55, access_color; bend=0.08, figstyle)
        text!(ax, 0.49, 0.82;
            text="exclusion\neffect", color=access_color,
            fontsize=pt(figstyle, 10.8), font=:bold, align=(:left, :center))
    end

    if is_economic_row && length(variant_curves) >= 2
        tax_curve = variant_curves[1]
        gear_curve = variant_curves[2]
        tax_color = withalpha(RENT_RED, 0.94)
        gear_color = withalpha(SPILLOVER_GREEN, 0.94)

        draw_curve_transfer_arrow!(ax, y0, Γ0, tax_curve.y, tax_curve.Γ,
            0.30, 0.65, tax_color; bend=0.08, figstyle)
        text!(ax, 0.50, 0.66;
            text="royalty", color=tax_color,
            fontsize=pt(figstyle, 10.6), font=:bold,
            align=(:center, :bottom), lineheight=0.82)
        text!(ax, 0.50, 0.615;
            text=L"p(1-\rho)", color=tax_color,
            fontsize=pt(figstyle, 10.6), font=:bold,
            align=(:center, :bottom))

        draw_curve_transfer_arrow!(ax, y0, Φ0, gear_curve.y, gear_curve.Φ,
            0.30, 0.24, gear_color; figstyle)
        text!(ax, 0.32, 0.42;
            text="gear\nsubsidy", color=gear_color,
            fontsize=pt(figstyle, 10.6), font=:bold,
            align=(:left, :bottom), lineheight=0.82)
    end

    if (is_protected_row || is_economic_row) && !is_tradable_row
        for badge in scenario_badges
            draw_number_badge!(ax, badge.x, badge.y, badge.j, badge.color, figstyle;
                marker=badge.marker)
        end
    end

    return ax
end

function income_panel_limits(sol)
    x = steady_state(sol)
    p = sol.prob.p
    inc = incomes(x, p)
    idx = sortperm(baseline_thresholds_for(p, x, steady_time(sol)))
    total = inc.total[idx]
    outside_only = inc.wages_0[idx]

    if p.policy isa TradableUseRights
        trade = inc.trade[idx]
        trade_neg = min.(trade, 0.0)
        trade_pos = max.(trade, 0.0)
        top = trade_neg .+ inc.wages[idx] .+ inc.resource[idx] .+ trade_pos
        ymin = min(0.0, minimum(trade_neg), minimum(total))
        ymax = max(maximum(top), maximum(total), eps())
    else
        ymin = min(0.0, minimum(total), minimum(outside_only))
        ymax = max(maximum(total), maximum(outside_only), eps())
    end
    ypad = 0.08 * max(ymax - ymin, eps())
    return (ymin - 1.20 * ypad, ymax + 1.15 * ypad)
end

function draw_income_scenario_panel!(ax, sol, label, color, j, style, figstyle;
        annotate=false, show_xlabel=true, shared_ylims=nothing)
    style_income_axis!(ax)
    ax.yticklabelsvisible = true
    ax.yticksvisible = true
    ax.yticklabelsize = pt(figstyle, 8.6)
    ax.ylabelvisible = j == 1
    ax.ylabel = j == 1 ? "income" : ""
    ax.ylabelsize = pt(figstyle, 9.6)
    ax.ylabelcolor = MUTED
    ax.leftspinevisible = true
    ax.leftspinecolor = RGBAf(0.12, 0.16, 0.20, 0.22)
    ax.bottomspinevisible = false
    ax.topspinevisible = false
    ax.rightspinevisible = false
    ax.spinewidth = 0.6
    if style == :cards
        ax.backgroundcolor = withalpha(color, 0.055)
    end

    x = steady_state(sol)
    p = sol.prob.p
    inc = incomes(x, p)
    sort_values = baseline_thresholds_for(p, x, steady_time(sol))
    idx = sortperm(sort_values)
    total = inc.total[idx]
    outside_only = inc.wages_0[idx]

    is_tradable = p.policy isa TradableUseRights
    trade = is_tradable ? inc.trade[idx] : Float64[]
    trade_neg = is_tradable ? min.(trade, 0.0) : Float64[]
    trade_pos = is_tradable ? max.(trade, 0.0) : Float64[]
    ymin_plot, ymax_plot = isnothing(shared_ylims) ? income_panel_limits(sol) : shared_ylims

    if style == :cards
        poly!(ax, Rect2f(0.35, ymin_plot, 0.42, ymax_plot - ymin_plot);
            color=withalpha(color, 0.88), strokewidth=0)
    end
    incomes_plot!(ax, sol; order=true, sort_values,
        color=withalpha(color, style == :badges ? 0.58 : 0.64),
        resource_incomes=false, active_coloring=true,
        active_color=withalpha(color, style == :badges ? 0.66 : 0.72),
        inactive_color=withalpha(GRAY, 0.66),
        show_active=false, state=x, time=steady_time(sol),
        annotate_rent_reallocation=is_tradable,
        rent_arrow_scale=1.0)
    if is_tradable && j == 1
        neg_ids = findall(<(0.0), trade_neg)
        pos_ids = findall(>(0.0), trade_pos)
        if !isempty(neg_ids) && !isempty(pos_ids)
            pos_i = pos_ids[cld(length(pos_ids), 2)]
            added_base = trade_neg[pos_i] + inc.wages[idx][pos_i] + inc.resource[idx][pos_i]
            stop = Point2f(pos_i, added_base + 0.50 * trade_pos[pos_i])
            yrange = ymax_plot - ymin_plot
            label_x = clamp(stop[1] - 0.07 * p.N, 0.52 * p.N, 0.78 * p.N)
            label_y = clamp(stop[2] - 0.28 * yrange, ymin_plot, ymax_plot)
            text!(ax, label_x, label_y;
                text="rent reallocation", color=RGBAf(0.82, 0.12, 0.13, 0.94),
                fontsize=pt(figstyle, 10.4), font=:bold, align=(:left, :center))
        end
    end
    hlines!(ax, [0.0]; color=RGBAf(0.12, 0.16, 0.20, 0.24), linewidth=0.8)

    badge = style == :badges ? (j == 1 ? "● 1" : "◆ 2") : string(j)
    summary = @sprintf("Res. rent %.2f  ·  Total inc. %.2f\nGini %.2f",
        sum(inc.resource_rent), sum(inc.total), inc.gini)
    income_panel_heading!(ax, "$badge  $(scenario_label(label))", summary;
        color, summary_color=MUTED,
        fontsize=pt(figstyle, 11.6))
    ax.xlabelvisible = show_xlabel
    ax.xlabel = "actors ordered by exit threshold θᵢ"
    ax.xlabelsize = pt(figstyle, 12.2)
    ax.xlabelfont = :bold
    ax.xlabelcolor = MUTED
    xlims!(ax, 0.5, p.N + 0.5)
    ylims!(ax, ymin_plot, ymax_plot)
    return ax
end

function shared_income_limits(rows)
    panel_limits = [income_panel_limits(v.sol) for row in rows for v in row.variants]
    return (
        minimum(first.(panel_limits)),
        maximum(last.(panel_limits)),
    )
end

function draw_income_pair_option!(layout, row, style, figstyle; annotate=false,
        show_xlabel=false, shared_ylims=nothing)
    pair_only = isnothing(shared_ylims)
    pair_only && (shared_ylims = shared_income_limits([row]))
    if pair_only && row.title == "Tradable use rights"
        # Transfers span the full width, so keep the inset above their positive bars.
        lo, hi = shared_ylims
        shared_ylims = (lo, hi + 0.30 * (hi - lo))
    end
    axes = Axis[]
    for (j, v) in enumerate(row.variants)
        ax = Axis(layout[j, 1])
        color = option_colors(style, j, v)
        draw_income_scenario_panel!(ax, v.sol, v.label, color, j, style, figstyle;
            annotate=annotate && j == 1,
            show_xlabel=show_xlabel && j == length(row.variants),
            shared_ylims)
        push!(axes, ax)
    end
    rowgap!(layout, style == :cards ? 6 : 2)
    return axes
end

function option_title(style)
    style == :fixed_hues && return "Policies as transformations of attractor geometry"
    style == :badges && return "Option B: line style and numbered markers"
    return "Option C: paired scenario cards"
end

function option_subtitle(style)
    style == :fixed_hues &&
        return "Two scenarios are overlaid in each phase diagram; the matched income panels use the same two colors."
    style == :badges &&
        return "Policy-family hues remain available, while scenario identity is encoded by solid/circle versus dashed/diamond."
    return "Each scenario is treated as a colored card; the phase labels and stacked income panels use matching cards."
end

"""Render policy comparisons with income_scale=:all (or :policy for row-wise scales)."""
function figure4(; outdir=joinpath(@__DIR__, "figures"),
        save_outputs=true, figstyle=paper_figure_style(px_per_unit=3), income_scale=:all)
    income_scale in (:all, :policy) || throw(ArgumentError("income_scale must be :all or :policy"))
    style = :fixed_hues
    rows, oa_sol = policy_rows()
    shared_ylims = income_scale == :all ? shared_income_limits(rows) : nothing
    income_axes = Axis[]
    fig = Figure(size=figsize(figstyle), backgroundcolor=:white, fontsize=pt(figstyle, 13))

    Label(fig[0, 1:3], option_title(style); fontsize=pt(figstyle, 24), font=:bold,
        color=DARK, tellwidth=false)
    Label(fig[1, 1:3], option_subtitle(style); fontsize=pt(figstyle, 12.2),
        color=withalpha(MUTED, 0.96), tellwidth=false)
    Label(fig[2, 1], "Policy instrument\nnon-dimensionalized value function",
        fontsize=pt(figstyle, 15.0), font=:bold, color=DARK, tellwidth=false)
    Label(fig[2, 2], "Phase diagram:\ntwo scenarios overlaid",
        fontsize=pt(figstyle, 15.0), font=:bold, color=DARK, tellwidth=false)
    Label(fig[2, 3], "Income distributions\nsorted by exit thresholds θᵢ",
        fontsize=pt(figstyle, 15.0), font=:bold, color=DARK, tellwidth=false)

    for (r, row) in enumerate(rows)
        is_bottom_row = r == length(rows)
        policy_ax = Axis(fig[r + 2, 1])
        draw_policy_info_panel!(policy_ax, row, figstyle)

        phase_ax = Axis(fig[r + 2, 2])
        draw_phase_pairing!(phase_ax, row, oa_sol, style, figstyle;
            show_xlabel=is_bottom_row)

        income_grid = GridLayout(fig[r + 2, 3])
        axes = draw_income_pair_option!(income_grid, row, style, figstyle;
            annotate=r == 1, show_xlabel=is_bottom_row, shared_ylims)
        append!(income_axes, axes)
    end

    if income_scale == :all
        linkyaxes!(income_axes...)
        ylims!(first(income_axes), shared_ylims...)
    end

    rowsize!(fig.layout, 0, Auto(0.26))
    rowsize!(fig.layout, 1, Auto(0.20))
    rowsize!(fig.layout, 2, Auto(0.18))
    colsize!(fig.layout, 1, Relative(1 / 3))
    colsize!(fig.layout, 2, Relative(1 / 3))
    colsize!(fig.layout, 3, Relative(1 / 3))
    colgap!(fig.layout, 12)
    rowgap!(fig.layout, 12)

    paths = String[]
    if save_outputs
        isdir(outdir) || mkpath(outdir)
        png = joinpath(outdir, "figure4.png")
        pdf = joinpath(outdir, "figure4.pdf")
        save(png, fig, px_per_unit=px_per_unit(figstyle))
        save(pdf, fig)
        append!(paths, [png, pdf])
    end
    return fig, paths
end

if abspath(PROGRAM_FILE) == @__FILE__
    _, paths = figure4()
    println("Wrote:")
    foreach(path -> println("  ", path), paths)
end
