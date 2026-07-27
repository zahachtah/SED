#!/usr/bin/env julia

using CairoMakie
using SED
using Statistics

CairoMakie.activate!()

const DARK = RGBf(0.11, 0.13, 0.16)
const MUTED = RGBf(0.43, 0.48, 0.57)
const GRID = RGBAf(0.12, 0.16, 0.20, 0.08)
const SHADE = RGBAf(0.0, 0.0, 0.0, 0.055)
const ORANGE = RGBf(0.95, 0.47, 0.04)
const FOREST_GREEN = RGBf(0.13, 0.45, 0.20)
const RED = RGBf(0.85, 0.08, 0.22)
const BLUE = RGBf(0.18, 0.43, 0.78)
const STEELBLUE = RGBf(0.27, 0.51, 0.71)
const GRAY = RGBf(0.72, 0.74, 0.77)
const FIG3_N = 100
const BASE_TOTAL_IMPACT = 1.45
const SCENARIO_LINEWIDTH = 3.0
const SCENARIO_IMPACT_WIDTH = 2.4
const BASE_LINEWIDTH = SCENARIO_LINEWIDTH + 2.0
const BASE_IMPACT_WIDTH = SCENARIO_IMPACT_WIDTH + 2.0
const FIG3_TITLE = 31
const FIG3_COLUMN_TITLE = 22
const FIG3_AXIS_LABEL = 20
const FIG3_TICK_LABEL = 15.5
const FIG3_PANEL_LABEL = 24
const FIG3_ATTRACTOR_MARKER = 20
const FIG3_ANNOTATION = 20
const FIG3_SMALL_ANNOTATION = 17.0
const FIG3_PAIR_TITLE = 18
const FIG3_PAIR_TEXT = 16

withalpha(c, a) = RGBAf(c.r, c.g, c.b, a)
distdata(x) = hasproperty(x, :data) ? x.data : x

function impact_profile(total=BASE_TOTAL_IMPACT; orientation=:flat, N=FIG3_N)
    r = collect(range(0.0, 1.0, length=N))
    raw = if orientation == :flat
        ones(N)
    elseif orientation == :positive
        0.30 .+ r .^ 2.15
    elseif orientation == :negative
        0.30 .+ reverse(r) .^ 2.15
    else
        error("orientation must be :flat, :positive, or :negative")
    end
    return raw ./ sum(raw) .* total
end

function ordered_thresholds(; median=0.3, sigma=0.8, distribution=LogNormal, N=FIG3_N)
    d = dist(median=median, sigma=sigma, distribution=distribution)
    sample!(d, N; random=false)
    return copy(d.data)
end

function style_phase_axis!(ax; xlabel=false, ylabel=false)
    ax.xgridcolor = GRID
    ax.ygridcolor = GRID
    ax.xticklabelcolor = MUTED
    ax.yticklabelcolor = MUTED
    ax.xlabelcolor = DARK
    ax.ylabelcolor = DARK
    ax.titlecolor = DARK
    ax.spinewidth = 0.8
    spine = RGBAf(0.12, 0.16, 0.20, 0.16)
    ax.bottomspinecolor = spine
    ax.leftspinecolor = spine
    ax.topspinevisible = false
    ax.rightspinevisible = false
    ax.xticks = 0:0.5:1
    ax.yticks = 0:0.5:1
    ax.xlabel = xlabel ? "Resource level, y" : ""
    ax.ylabel = ylabel ? "Participation (share of all actors)" : ""
    ax.xlabelsize = FIG3_AXIS_LABEL
    ax.ylabelsize = FIG3_AXIS_LABEL
    ax.xticklabelsize = FIG3_TICK_LABEL
    ax.yticklabelsize = FIG3_TICK_LABEL
    xlims!(ax, 0, 1)
    ylims!(ax, 0, 1)
    return ax
end

function steady_state(sol)
    i = max(1, length(sol.t) - 2)
    return sol.u[i], sol.t[i]
end

function participation(sol)
    p = sol.prob.p
    x, t = steady_state(sol)
    lim = p.limit(x, p, t)
    return clamp(mean(clamp.(x[1:p.N] ./ lim, 0.0, 1.0)), 0.0, 1.0)
end

function attractor(sol)
    x, _ = steady_state(sol)
    return clamp(x[sol.prob.p.N+1], 0.0, 1.0), participation(sol)
end

function curves_for(sol; n=320)
    p = sol.prob.p
    x, t = steady_state(sol)
    y = collect(range(0.0, 1.0, length=n))
    incentive = [Γ(yy, p; x=copy(x), t=t) for yy in y]
    impact = [Φ(yy, p; t=t) for yy in y]
    return y, incentive, impact
end

function phase_background!(ax)
    poly!(ax, Rect2f(0, 0, 0.5, 1); color=SHADE, strokewidth=0)
    return ax
end

function draw_curves!(ax, sol; incentive_color=STEELBLUE, impact_color=STEELBLUE,
        show_incentive=true, show_impact=true, impact_style=:dash,
        linewidth=3.0, impact_width=2.2, markercolor=:black,
        alpha=1.0, mark=true)
    y, inc, imp = curves_for(sol)
    show_incentive && lines!(ax, y, inc; color=withalpha(incentive_color, alpha), linewidth)
    show_impact && lines!(ax, y, imp; color=withalpha(impact_color, alpha),
        linewidth=impact_width, linestyle=impact_style)
    if mark
        yy, pp = attractor(sol)
        scatter!(ax, [yy], [pp]; color=markercolor, markersize=FIG3_ATTRACTOR_MARKER,
            strokecolor=:white, strokewidth=1.2)
    end
    return ax
end

function panel_label!(ax, label)
    text!(ax, 0.025, 0.955; text=label, color=DARK, fontsize=FIG3_PANEL_LABEL,
        font=:bold, align=(:left, :top))
end

function draw_scenario_badge!(ax, x, y, n; color=STEELBLUE, markersize=17,
        fontsize=9.3)
    scatter!(ax, [x], [y]; color, markersize,
        strokecolor=:white, strokewidth=1.0)
    text!(ax, x, y; text=string(n), color=:white, fontsize,
        font=:bold, align=(:center, :center))
end

function interp_curve_point(xs, ys, x)
    x = clamp(x, first(xs), last(xs))
    i = clamp(searchsortedlast(xs, x), 1, length(xs) - 1)
    x0, x1 = xs[i], xs[i + 1]
    y0, y1 = ys[i], ys[i + 1]
    t = isapprox(x0, x1) ? 0.0 : clamp((x - x0) / (x1 - x0), 0.0, 1.0)
    return Point2f(x, y0 + t * (y1 - y0))
end

function curve_circle_intersection(xs, ys, center, radius)
    radial_error(x, y) = (x - center[1])^2 + (y - center[2])^2 - radius^2
    errors = radial_error.(xs, ys)
    for i in 2:length(xs)
        e0, e1 = errors[i - 1], errors[i]
        if e0 == 0
            return Point2f(xs[i - 1], ys[i - 1])
        elseif e0 * e1 <= 0
            t = abs(e0) / max(abs(e0) + abs(e1), eps())
            return Point2f(
                xs[i - 1] + t * (xs[i] - xs[i - 1]),
                ys[i - 1] + t * (ys[i] - ys[i - 1]),
            )
        end
    end
    return Point2f(xs[argmin(abs.(errors))], ys[argmin(abs.(errors))])
end

function x_at_curve_level(xs, ys, level)
    for i in 2:length(xs)
        y0, y1 = ys[i - 1], ys[i]
        if (y0 <= level <= y1) || (y1 <= level <= y0)
            denom = y1 - y0
            abs(denom) < eps() && return 0.5 * (xs[i - 1] + xs[i])
            t = (level - y0) / denom
            return xs[i - 1] + t * (xs[i] - xs[i - 1])
        end
    end
    return xs[argmin(abs.(ys .- level))]
end

function curve_point_slope(xs, ys, x)
    x = clamp(x, first(xs), last(xs))
    i = clamp(searchsortedlast(xs, x), 1, length(xs) - 1)
    x0, x1 = xs[i], xs[i + 1]
    y0, y1 = ys[i], ys[i + 1]
    denom = max(x1 - x0, eps())
    t = clamp((x - x0) / denom, 0.0, 1.0)
    return Point2f(x, y0 + t * (y1 - y0)), (y1 - y0) / denom
end

function curve_normal_towards(slope, target_direction)
    n = Vec2f(-slope, 1.0)
    n = n / max(sqrt(n[1]^2 + n[2]^2), eps())
    (n[1] * target_direction[1] + n[2] * target_direction[2]) < 0 && (n = -n)
    return n
end

function draw_arc_arrow_deg!(ax, origin, radius, start_angle_deg, stop_angle_deg;
        linewidth=2.0, color=STEELBLUE, linestyle=:solid, startarrow=false,
        tipwidth=26, tiplength=30, headlength=0.075)
    deg2rad(θ) = θ * π / 180
    θs = collect(range(start_angle_deg, stop_angle_deg, length=100))
    pts = [Point2f(origin[1] + radius * cos(deg2rad(90 - θ)),
        origin[2] + radius * sin(deg2rad(90 - θ))) for θ in θs]
    lines!(ax, pts; color, linewidth, linestyle)
    if startarrow
        start_index = findfirst(i -> hypot((pts[i] - pts[1])...) >= headlength,
            eachindex(pts))
        start_index = isnothing(start_index) ? length(pts) : start_index
        head_delta = pts[1] - pts[start_index]
        arrows2d!(ax, [pts[start_index]], [head_delta];
            color, shaftwidth=linewidth, tipwidth, tiplength)
    end
    head_index = findfirst(i -> hypot((pts[end] - pts[i])...) <= headlength,
        eachindex(pts))
    head_index = isnothing(head_index) ? 1 : max(1, head_index - 1)
    head_start = pts[head_index]
    arrows2d!(ax, [head_start], [pts[end] - head_start];
        color, shaftwidth=linewidth, tipwidth, tiplength)
    return ax
end

function draw_bezier_arrow!(ax, start::Point2f, stop::Point2f, control::Point2f;
        linewidth=2.0, color=STEELBLUE, tipwidth=24, tiplength=28)
    ts = collect(range(0.0, 1.0, length=100))
    pts = Point2f[]
    for t in ts
        s = 1.0 - t
        push!(pts, Point2f(
            s^2 * start[1] + 2 * s * t * control[1] + t^2 * stop[1],
            s^2 * start[2] + 2 * s * t * control[2] + t^2 * stop[2],
        ))
    end
    lines!(ax, pts; color, linewidth)
    head_start = pts[max(1, length(pts) - 8)]
    arrows2d!(ax, [head_start], [pts[end] - head_start];
        color, shaftwidth=linewidth, tipwidth, tiplength)
    return ax
end

function draw_normal_transfer_arrow!(ax, xs0, ys0, xs1, ys1, x_start, x_stop, color;
        linewidth=2.0, tipwidth=24, tiplength=28)
    start, slope_start = curve_point_slope(xs0, ys0, x_start)
    stop, slope_stop = curve_point_slope(xs1, ys1, x_stop)
    direction = stop - start
    dist = max(sqrt(direction[1]^2 + direction[2]^2), eps())
    n_start = curve_normal_towards(slope_start, direction)
    n_stop = curve_normal_towards(slope_stop, direction)
    control_len = clamp(0.58 * dist, 0.055, 0.16)
    c1 = start + n_start * control_len
    c2 = stop - n_stop * control_len

    ts = collect(range(0.0, 1.0, length=100))
    pts = Point2f[]
    for t in ts
        s = 1.0 - t
        push!(pts, Point2f(
            s^3 * start[1] + 3 * s^2 * t * c1[1] + 3 * s * t^2 * c2[1] + t^3 * stop[1],
            s^3 * start[2] + 3 * s^2 * t * c1[2] + 3 * s * t^2 * c2[2] + t^3 * stop[2],
        ))
    end
    lines!(ax, pts; color, linewidth)
    head_start = pts[max(1, length(pts) - 8)]
    arrows2d!(ax, [head_start], [pts[end] - head_start];
        color, shaftwidth=linewidth, tipwidth, tiplength)
    return ax
end

function style_pair_axis!(ax; xlabel=false, ylabel=false)
    ax.xgridcolor = GRID
    ax.ygridcolor = GRID
    ax.xticklabelcolor = MUTED
    ax.yticklabelcolor = MUTED
    ax.xlabelcolor = DARK
    ax.ylabelcolor = DARK
    ax.titlecolor = STEELBLUE
    ax.spinewidth = 0.8
    spine = RGBAf(0.12, 0.16, 0.20, 0.16)
    ax.bottomspinecolor = spine
    ax.leftspinecolor = spine
    ax.topspinevisible = false
    ax.rightspinevisible = false
    ax.xlabel = xlabel ? "exit threshold, θᵢ" : ""
    ax.ylabel = ylabel ? "impact potential, ūᵢ" : ""
    ax.xlabelsize = FIG3_AXIS_LABEL
    ax.ylabelsize = FIG3_AXIS_LABEL
    ax.xticklabelsize = FIG3_TICK_LABEL
    ax.yticklabelsize = FIG3_TICK_LABEL
    ax.xticks = 0:0.5:1
    return ax
end

function draw_pairing_panel!(ax, sol; scenario_number, scenario_text,
        subtext, mechanism_text, scenario_color=STEELBLUE,
        xlabel=false, ylabel=false, badge_x=0.08,
        title_y_frac=0.91, sub_y_frac=0.68, mechanism_y_frac=0.52,
        panel_id=nothing)
    style_pair_axis!(ax; xlabel, ylabel)
    p = sol.prob.p
    thresholds = distdata(p.w̃)
    impacts = distdata(p.ū)
    idx = sortperm(thresholds)
    lines!(ax, thresholds[idx], impacts[idx]; color=withalpha(scenario_color, 0.66),
        linewidth=2.2)
    scatter!(ax, thresholds[idx], impacts[idx]; color=withalpha(scenario_color, 0.88),
        markersize=4.0)
    xlims!(ax, 0, 1)
    ymax = maximum(impacts) * 1.10
    ylims!(ax, 0, ymax)
    text_x = badge_x + 0.04
    title_y = title_y_frac * ymax
    sub_y = sub_y_frac * ymax
    mech_y = mechanism_y_frac * ymax
    if panel_id !== nothing
        text!(ax, 0.025, 0.955ymax; text=panel_id, color=DARK,
            fontsize=FIG3_PANEL_LABEL, font=:bold, align=(:left, :top))
    end
    draw_scenario_badge!(ax, badge_x, title_y, scenario_number;
        color=scenario_color, markersize=17, fontsize=9.2)
    text!(ax, text_x, title_y; text=scenario_text, color=scenario_color,
        fontsize=FIG3_PAIR_TITLE, font=:bold, align=(:left, :center))
    text!(ax, text_x, sub_y; text=subtext, color=scenario_color,
        fontsize=FIG3_PAIR_TEXT, align=(:left, :center))
    if !isempty(strip(mechanism_text))
        text!(ax, text_x, mech_y; text=mechanism_text,
            color=withalpha(MUTED, 0.98), fontsize=FIG3_PAIR_TEXT,
            align=(:left, :top), justification=:left)
    end
    return ax
end

function heatmap_dynamics!(ax, s)
    sol = sim(scenario(s; α=0.05), t_end=1000.0)
    p = sol.prob.p
    states = hcat(sol.u...)
    thresholds = distdata(p.w̃)
    order = sortperm(thresholds)
    lim = p.limit(sol.u[end], p, sol.t[end])
    use_fraction = clamp.(states[1:p.N, :] ./ lim, 0.0, 1.0)

    heatmap!(ax, sol.t .+ 1.0, thresholds[order], permutedims(use_fraction[order, :]);
        colormap=cgrad([:white, RGBf(1.0, 0.58, 0.06), ORANGE]),
        colorrange=(0.0, 1.0))
    ax.xlabel = "time →"
    ax.ylabel = "actor's exit threshold, θᵢ"
    ax.yaxisposition = :right
    ax.xscale = log10
    ax.xlabelsize = FIG3_AXIS_LABEL
    ax.ylabelsize = FIG3_AXIS_LABEL
    ax.xticklabelsize = FIG3_TICK_LABEL
    ax.yticklabelsize = FIG3_TICK_LABEL
    ax.xgridvisible = false
    ax.ygridvisible = false
    ax.spinewidth = 0.8
    ax.topspinevisible = false
    ax.leftspinevisible = false
    xlims!(ax, 1.0, maximum(sol.t) + 1.0)
    ylims!(ax, 0.0, 1.0)

    elements = [
        PolyElement(color=ORANGE, strokecolor=GRAY, strokewidth=1),
        PolyElement(color=RGBAf(1.0, 0.58, 0.06, 0.52), strokecolor=GRAY, strokewidth=1),
        PolyElement(color=:white, strokecolor=GRAY, strokewidth=1),
    ]
    axislegend(ax, elements, ["full use", "partial use", "no use"],
        "Individual actor's\nresource use over time";
        framevisible=false, rowgap=0, labelsize=FIG3_TICK_LABEL, titlesize=FIG3_AXIS_LABEL,
        position=:rt)
    panel_label!(ax, "f)")
end

function figure3_relational_variables(; outdir=joinpath(@__DIR__, "figures"),
        save_outputs=true)
    base_thresholds = ordered_thresholds(median=0.3, sigma=0.8)
    base_s = scenario(high_impact(N=FIG3_N);
        w̃=dist(data=base_thresholds),
        ū=dist(data=impact_profile()))
    fig = Figure(size=(1320, 980), backgroundcolor=:white, fontsize=17,
        figure_padding=(26, 20, 24, 24))

    Label(fig[1, 1], "Exit threshold", fontsize=FIG3_COLUMN_TITLE, font=:bold, color=DARK, tellwidth=false)
    Label(fig[1, 2], "Impact", fontsize=FIG3_COLUMN_TITLE, font=:bold, color=DARK, tellwidth=false)
    Label(fig[1, 3], "Dynamics", fontsize=FIG3_COLUMN_TITLE, font=:bold, color=DARK, tellwidth=false)

    ax_a = Axis(fig[2, 1])
    ax_b = Axis(fig[3, 1])
    ax_c = Axis(fig[2, 2])
    ax_d = Axis(fig[3, 2])
    ax_e = Axis(fig[2, 3])
    pairing_grid = GridLayout(fig[3, 3])
    Label(pairing_grid[1, 1], "Covariation in ūᵢ and θᵢ";
        fontsize=FIG3_COLUMN_TITLE, font=:bold, color=DARK, tellwidth=false)
    ax_f = Axis(pairing_grid[2, 1])
    ax_g = Axis(pairing_grid[3, 1])

    for (ax, showx, showy) in [
            (ax_a, false, true), (ax_b, true, true),
            (ax_c, false, false), (ax_d, true, false),
            (ax_e, false, false)]
        style_phase_axis!(ax; xlabel=showx, ylabel=showy)
        phase_background!(ax)
    end

    # A: variance/inequality in exit thresholds, same median and same impacts.
    sigma_sols = [
        sim(scenario(base_s; w̃=dist(median=0.5, sigma=0.8, distribution=LogNormal))),
        sim(scenario(base_s; w̃=dist(median=0.5, sigma=0.3, distribution=LogNormal))),
        sim(scenario(base_s; w̃=dist(median=0.5, sigma=0.0, distribution=LogNormal))),
    ]
    draw_curves!(ax_a, sigma_sols[1]; impact_color=GRAY,
        impact_width=BASE_IMPACT_WIDTH, linewidth=SCENARIO_LINEWIDTH)
    draw_curves!(ax_a, sigma_sols[2]; show_impact=false, linewidth=SCENARIO_LINEWIDTH)
    draw_curves!(ax_a, sigma_sols[3]; show_impact=false, linewidth=SCENARIO_LINEWIDTH)
    draw_arc_arrow_deg!(ax_a, Point2f(0.50, 0.50), 0.36, 0, 55;
        color=STEELBLUE, linewidth=4.2, linestyle=:solid,
        tipwidth=20, tiplength=23, headlength=0.085)
    text!(ax_a, 0.68, 0.57; text="Increasing\nthreshold\ninequality",
        color=STEELBLUE, fontsize=FIG3_ANNOTATION, align=(:left, :center))
    text!(ax_a, 0.55, 0.34; text="pushes the\nattractor left",
        color=DARK, fontsize=FIG3_ANNOTATION, align=(:left, :center))
    panel_label!(ax_a, "a)")

    # B: additive versus multiplicative shifts in exit thresholds.
    threshold_base = ordered_thresholds(median=0.50, sigma=0.52)
    threshold_sols = [
        sim(scenario(base_s; w̃=dist(data=threshold_base))),
        sim(scenario(base_s; w̃=dist(data=threshold_base .+ 0.30))),
        sim(scenario(base_s; w̃=dist(data=threshold_base .* 1.4))),
    ]
    draw_curves!(ax_b, threshold_sols[1]; incentive_color=GRAY, impact_color=GRAY,
        impact_width=BASE_IMPACT_WIDTH, linewidth=BASE_LINEWIDTH,
        markercolor=GRAY)
    draw_curves!(ax_b, threshold_sols[2]; show_impact=false,
        incentive_color=STEELBLUE, linewidth=SCENARIO_LINEWIDTH,
        markercolor=:black)
    draw_curves!(ax_b, threshold_sols[3]; show_impact=false,
        incentive_color=ORANGE, linewidth=SCENARIO_LINEWIDTH,
        markercolor=:black)
    y_base, Γ_base, _ = curves_for(threshold_sols[1])
    y_additive, Γ_additive, _ = curves_for(threshold_sols[2])
    y_multiplicative, Γ_multiplicative, _ = curves_for(threshold_sols[3])
    additive_level = 0.43
    additive_start = x_at_curve_level(y_base, Γ_base, additive_level)
    additive_stop = x_at_curve_level(y_additive, Γ_additive, additive_level)
    arrows2d!(ax_b, [Point2f(additive_start + 0.018, additive_level)],
        [Vec2f(additive_stop - additive_start - 0.036, 0.0)];
        color=STEELBLUE, shaftwidth=2.4, tipwidth=15, tiplength=18)
    mult_start = x_at_curve_level(y_base, Γ_base, 0.72)
    mult_start_point = interp_curve_point(y_base, Γ_base, mult_start)
    mult_stop_point = interp_curve_point(y_multiplicative, Γ_multiplicative, 0.80)
    mult_delta = mult_stop_point - mult_start_point
    arrows2d!(ax_b, [mult_start_point], [mult_delta];
        color=ORANGE, shaftwidth=2.4, tipwidth=15, tiplength=18)
    text!(ax_b, 0.72, 0.32; text="Additive\nθᵢ + 0.30",
        color=STEELBLUE, fontsize=FIG3_ANNOTATION, align=(:left, :center))
    text!(ax_b, 0.58, 0.80; text="Multiplicative\n1.4θᵢ",
        color=ORANGE, fontsize=FIG3_ANNOTATION, align=(:left, :center))
    panel_label!(ax_b, "b)")

    # C: mean impact potential.
    draw_curves!(ax_c, sim(base_s); incentive_color=GRAY, impact_color=GRAY,
        linewidth=BASE_LINEWIDTH, impact_width=BASE_IMPACT_WIDTH)
    impact_sols = [
        sim(scenario(base_s; ū=dist(data=impact_profile(1.02)))),
        sim(scenario(base_s; ū=dist(data=impact_profile(2.28)))),
    ]
    for sol in impact_sols
        draw_curves!(ax_c, sol; show_incentive=false, impact_color=STEELBLUE,
            impact_style=:dash, impact_width=SCENARIO_IMPACT_WIDTH,
            markercolor=:black)
    end
    upper_y, _, upper_impact = curves_for(impact_sols[1])
    lower_y, _, lower_impact = curves_for(impact_sols[2])
    arc_center = Point2f(1.0, 0.0)
    arrow_start = interp_curve_point(upper_y, upper_impact, 0.50)
    arc_radius = hypot(arrow_start[1] - arc_center[1], arrow_start[2] - arc_center[2])
    arrow_stop = curve_circle_intersection(lower_y, lower_impact, arc_center, arc_radius)
    start_angle = 90 - rad2deg(atan(arrow_start[2] - arc_center[2],
        arrow_start[1] - arc_center[1]))
    stop_angle = 90 - rad2deg(atan(arrow_stop[2] - arc_center[2],
        arrow_stop[1] - arc_center[1]))
    draw_arc_arrow_deg!(ax_c, arc_center, arc_radius, start_angle, stop_angle;
        color=STEELBLUE, linewidth=4.2, linestyle=:solid,
        tipwidth=20, tiplength=23, headlength=0.085)
    text!(ax_c, arrow_start[1] + 0.035, arrow_start[2] + 0.015;
        text="Increasing\nimpact potential", color=STEELBLUE,
        fontsize=FIG3_ANNOTATION, align=(:left, :bottom))
    panel_label!(ax_c, "c)")

    # D: covariance/order between thresholds and impact potential.
    draw_curves!(ax_d, sim(base_s); incentive_color=GRAY, impact_color=GRAY,
        linewidth=BASE_LINEWIDTH, impact_width=BASE_IMPACT_WIDTH)
    corr_sols = [
        sim(scenario(base_s; ū=dist(data=impact_profile(orientation=:positive)))),
        sim(scenario(base_s; ū=dist(data=impact_profile(orientation=:negative)))),
    ]
    corr_colors = [STEELBLUE, ORANGE]
    corr_alpha = [1.0, 0.92]
    for (sol, col, alpha) in zip(corr_sols, corr_colors, corr_alpha)
        draw_curves!(ax_d, sol; show_incentive=false, impact_color=col,
            impact_style=:dash, impact_width=SCENARIO_IMPACT_WIDTH,
            markercolor=:black, alpha)
    end
    draw_scenario_badge!(ax_d, 0.47, 0.63, 1; color=STEELBLUE)
    text!(ax_d, 0.51, 0.62; text="Corr(θᵢ,ūᵢ) > 0",
        color=STEELBLUE, fontsize=FIG3_SMALL_ANNOTATION, font=:bold, align=(:left, :center))
    draw_scenario_badge!(ax_d, 0.32, 0.35, 2; color=ORANGE)
    text!(ax_d, 0.36, 0.35; text="Corr(θᵢ,ūᵢ) < 0",
        color=ORANGE, fontsize=FIG3_SMALL_ANNOTATION, font=:bold, align=(:left, :center))
    panel_label!(ax_d, "d-1)")

    # E: dynamics for two behavioral response rates.
    draw_curves!(ax_e, sim(base_s); incentive_color=GRAY, impact_color=GRAY,
        linewidth=BASE_LINEWIDTH, impact_width=BASE_IMPACT_WIDTH, mark=false)
    fast_sol = sim(base_s)
    slow_sol = sim(scenario(base_s; α=0.01))
    SED.trajectory_plot!(ax_e, fast_sol; color=FOREST_GREEN, startcolor=withalpha(FOREST_GREEN, 0.35), linewidth=2.4)
    SED.trajectory_plot!(ax_e, slow_sol; color=RED, startcolor=withalpha(RED, 0.35), linewidth=2.4)
    scatter!(ax_e, [attractor(fast_sol)[1]], [attractor(fast_sol)[2]];
        color=:black, markersize=FIG3_ATTRACTOR_MARKER, strokecolor=:white, strokewidth=1.2)
    text!(ax_e, 0.58, 0.905; text="Fast behavioral response",
        color=FOREST_GREEN, fontsize=FIG3_ANNOTATION, align=(:center, :center))
    text!(ax_e, 0.34, 0.705; text="Slow behavioral response",
        color=RED, fontsize=FIG3_ANNOTATION, align=(:center, :center))
    panel_label!(ax_e, "e)")

    # F-G: actor-level pairings that generate the two covariance curves in D.
    draw_pairing_panel!(ax_f, corr_sols[1]; scenario_number=1,
        scenario_text="Corr(θᵢ,ūᵢ) > 0",
        subtext="high-θᵢ users\ncarry more impact",
        mechanism_text="",
        scenario_color=STEELBLUE, ylabel=true, badge_x=0.40,
        title_y_frac=0.41, sub_y_frac=0.18, panel_id="d-2)")
    draw_pairing_panel!(ax_g, corr_sols[2]; scenario_number=2,
        scenario_text="Corr(θᵢ,ūᵢ) < 0",
        subtext="low-θᵢ users\ncarry more impact",
        mechanism_text="",
        scenario_color=ORANGE, xlabel=true, ylabel=true, badge_x=0.48,
        title_y_frac=0.64, sub_y_frac=0.40)
    rowgap!(pairing_grid, 8)

    colgap!(fig.layout, 28)
    rowgap!(fig.layout, 14)
    rowsize!(fig.layout, 1, Auto(0.16))

    paths = String[]
    if save_outputs
        isdir(outdir) || mkpath(outdir)
        png = joinpath(outdir, "figure3.png")
        pdf = joinpath(outdir, "figure3.pdf")
        alt_png = joinpath(outdir, "figure3_relational_variables.png")
        alt_pdf = joinpath(outdir, "figure3_relational_variables.pdf")
        save(png, fig, px_per_unit=2)
        save(pdf, fig)
        save(alt_png, fig, px_per_unit=2)
        save(alt_pdf, fig)
        append!(paths, [png, pdf, alt_png, alt_pdf])
    end
    return fig, paths
end

if abspath(PROGRAM_FILE) == @__FILE__
    _, paths = figure3_relational_variables()
    println("Wrote:")
    foreach(path -> println("  ", path), paths)
end
