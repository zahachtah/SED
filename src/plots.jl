using CairoMakie
using Colors
using ColorSchemes
using LinearAlgebra
using KernelDensity
using Printf
using Makie: LinearTicks  # for max tick count



function Γ_plot!(axis, sol; color=:darkorange, linewidth=3, t=0.0)
    y = range(0.0, stop=1.0, length=100)
    lines!(axis, y, Γ.(y, Ref(sol.prob.p), x=sol.u[end-1]; t); color, linewidth)
end

include("regulation_scan_plot.jl")

function Φ_plot!(axis, sol; color=:darkorange, linewidth=3, t=0.0)
    y = range(0.0, stop=1.0, length=100)
    lines!(axis, y, Φ.(y, Ref(sol.prob.p); t); color, linewidth)
end

function attractor_plot!(axis, sol; color=:darkorange, markersize=15, marker=:circle)
    N = sol.prob.p.N
    scatter!(axis, [sol[N+1, end-2]], [sum(sol[1:N, end-2] ./ sol.prob.p.limit(sol.u[end-2], sol.prob.p, sol.t[end-2]) ./ N)];
        color, markersize, marker)
end

function trajectory_plot!(axis, sol; color=:darkorange, startcolor=:lightgray, linewidth=2)
    scenario = sol.prob.p
    lines!(axis,
        [u[scenario.N+1] for u in sol.u[1:end-2]],
        [sum(u[1:scenario.N] ./ scenario.limit(u, scenario, sol.t[i])) / scenario.N for (i, u) in enumerate(sol.u[1:end-2])];
        color, linestyle=:dot, colormap=cgrad([startcolor, color], [0.0, 0.5, 1.0]), linewidth)
end

trajecory_plot! = trajectory_plot!

function bg_plot!(axis; show_exploitation=true)
    limits!(axis, 0.0, 1.0, 0.0, 1.0)
    if show_exploitation
        poly!(axis, Rect(0, 0, 0.5, 1), color=HSLA(10, 0.0, 0.5, 0.1))
    end
end

function target_plot!(axis, sol; color=:darkorange, linestyle=:dash, linewidth=3)
    scenario = sol.prob.p
    y = range(0.0, stop=1.0, length=100)
    if haskey(scenario, :policy_target)
        Y = scenario.policy_target == :effort ? ones(length(y)) : y
        lines!(axis, y, Φ.(1 .- (1 - scenario.regulation) ./ Y, Ref(scenario)); color, linewidth, linestyle)
    end
end

function dependency_graph_plot(s; node_color=:steelblue, edge_color=:gray, markersize=28, fontsize=12, figsize=(700, 450))
    fig = Figure(size=figsize)
    ax = Axis(fig[1, 1])
    dependency_graph_plot!(ax, s; node_color, edge_color, markersize, fontsize)
    fig
end

function dependency_graph_plot!(
    ax, s;
    node_color=:steelblue, edge_color=:gray,
    markersize=28, fontsize=12, figsize=(700, 450),
    label_colors::Union{Nothing,Dict{Symbol,Any}}=nothing
)
    g = dependency_graph(s)
    alpha_syms = Set{Symbol}((:α, :alpha))
    nodes = [k for k in g.nodes if !(k in alpha_syms)]
    edges_f = Dict{Symbol,Vector{Symbol}}()
    for k in nodes
        deps = get(g.edges, k, Symbol[])
        deps = [d for d in deps if !(d in alpha_syms)]
        edges_f[k] = deps
    end
    order_f = [k for k in get(g, :order, nodes) if k in nodes]
    children = Dict{Symbol,Vector{Symbol}}(k => Symbol[] for k in nodes)
    for (k, deps) in edges_f
        for d in deps
            push!(children[d], k)
        end
    end
    level = Dict{Symbol,Int}()
    for k in order_f
        deps = get(edges_f, k, Symbol[])
        level[k] = isempty(deps) ? 0 : maximum(get(level, d, 0) + 1 for d in deps)
    end
    for k in nodes
        if !haskey(level, k)
            deps = get(edges_f, k, Symbol[])
            level[k] = isempty(deps) ? 0 : maximum(get(level, d, 0) + 1 for d in deps)
        end
    end
    levels = Dict{Int,Vector{Symbol}}()
    for k in nodes
        l = level[k]
        get!(levels, l, Symbol[])
        push!(levels[l], k)
    end
    pos = Dict{Symbol,Point2f}()
    max_level = isempty(level) ? 0 : maximum(values(level))
    for (l, ks) in levels
        n = length(ks)
        xs = n == 1 ? [0.5f0] : collect(range(0.1, 0.9; length=n)) .|> Float32
        ys = fill(1.0f0 - (max_level == 0 ? 0.5f0 : l / (max_level + 0.5f0)), n)
        for (i, k) in enumerate(ks)
            pos[k] = Point2f(xs[i], ys[i])
        end
    end
    hidespines!(ax)
    hidedecorations!(ax; label=false, ticks=false, grid=false)
    if !isempty(pos)
        xs = map(p -> p[1], values(pos))
        ys = map(p -> p[2], values(pos))
        xmin, xmax = minimum(xs), maximum(xs)
        ymin, ymax = minimum(ys), maximum(ys)
        xspan = xmax - xmin
        yspan = ymax - ymin
        xpad = (xspan ≈ 0) ? 0.10 : 0.10 * xspan
        ypad = (yspan ≈ 0) ? 0.10 : 0.10 * yspan
        xlims!(ax, xmin - xpad, xmax + xpad)
        ylims!(ax, ymin - ypad, ymax + ypad)
    end
    r = 0.035
    for (k, deps) in edges_f
        for d in deps
            p1 = pos[d]
            p2 = pos[k]
            v = p2 - p1
            nv = norm(v)
            nv == 0 && continue
            u = v / nv
            start = p1 + u * r
            stop = p2 - u * r
            dxdy = stop - start
            arrows2d!(ax, [start], [dxdy]; color=edge_color, shaftwidth=2)
        end
    end
    pretty_label(sym::Symbol) = begin
        s = String(sym)
        if sym == Symbol("w̃") || occursin(r"^w(\\tilde|tilde)", s) || occursin(Char(0x0303), s)
            return "Incentive"
        elseif sym == Symbol("ū") || occursin(r"^u(\\bar|bar)", s) || occursin(Char(0x0304), s)
            return "Impact"
        else
            return s
        end
    end
    get_lab_color(sym::Symbol) = label_colors === nothing ? :black : get(label_colors, sym, :black)
    for (k, p) in pos
        text!(ax, p[1], p[2];
            text=pretty_label(k),
            align=(:center, :center),
            color=get_lab_color(k),
            fontsize=fontsize,
            font=:bold)
    end
    return ax
end

function phase_plot!(axis, sol; show_trajectory=false, show_target=false, open_access_color=:lightgray,
    incentive_line_color=:darkorange, impact_line_color=:darkorange, t=0.0,
    show_exploitation=true, show_oa=true, trajectory_color=:gray)
    show_exploitation && poly!(axis, Rect(0, 0, 0.5, 1), color=HSLA(10, 0.0, 0.5, 0.1))
    scenario = sol.prob.p
    N = scenario.N
    limits!(axis, 0.0, 1.0, 0.0, 1.0)
    y = range(0.0, stop=1.0, length=100)
    if show_oa
        # Create OA scenario using new API
        oa = change(scenario, policy=OpenAccess())
        lines!(axis, y, Γ.(y, Ref(oa), x=sol.u[end-1]), color=open_access_color, linewidth=3)
        lines!(axis, y, Φ.(y, Ref(oa)), color=open_access_color, linewidth=1)
    end
    lines!(axis, y, Γ.(y, Ref(scenario), x=sol.u[end-1]; t), color=incentive_line_color, linewidth=3)
    lines!(axis, y, Φ.(y, Ref(scenario); t), color=impact_line_color, linewidth=1)
    if show_target && haskey(scenario, :policy_target)
        Y = scenario.policy_target == :effort ? ones(length(y)) : y
        lines!(axis, y, Φ.(1 .- (1 - scenario.regulation) ./ Y, Ref(scenario)), color=:darkorange, linestyle=:dot)
    end
    if show_trajectory
        lines!(axis,
            [u[scenario.N+1] for u in sol.u[1:end-2]],
            [sum(u[1:scenario.N] ./ scenario.limit(u, scenario, sol.t[i])) / scenario.N for (i, u) in enumerate(sol.u[1:end-2])],
            color=scenario.policy isa Development ? sol.t[1:end-2] : trajectory_color,
            linestyle=:dot,
            colormap=cgrad([:lightgray, :darkorange], [0.0, 0.5, 1.0]))
    end
    scatter!(axis, [sol[N+1, end-2]], [sum(sol[1:N, end-2] ./ scenario.limit(sol.u[end-2], scenario, sol.t[end-2]) ./ N)], color=:black, markersize=10)
end

function phase_plot(sol)
    f = Figure()
    a = Axis(f[1, 1])
    phase_plot!(a, sol)
    f
end

function incomes_plot!(ax, sol; order=false, sort_by_incentives=false, color=:darkorange, dimensional::Bool=false, resource_incomes=true)
    inc = incomes(sol)
    res = inc.resource
    wage = inc.wages
    trd = inc.trade
    total = inc.total
    idx = order ? sort_by_incentives ? sortperm(sol.prob.p.w̃) : sortperm(total) : eachindex(total)
    barplot!(ax, (res[idx] .+ wage[idx]), color=color, alpha=1.0, offset=trd[idx])
    barplot!(ax, (res[idx]), color=:steelblue, alpha=1.0, offset=trd[idx])
    barplot!(ax, trd[idx], color=color)
    barplot!(ax, trd[idx], color=HSLA(0, 0, 0, 0.2))
end

function incomes_plot(sol; order=false, color=:darkorange, dimensional::Bool=false, sort_by_incentives=false, resource_incomes=true)
    f = Figure()
    incomes_plot!(Axis(f[1, 1]), sol; order, color, dimensional, resource_incomes, sort_by_incentives)
    f
end

function dist_plot!(ax, v; title="", kind=:line, bins=30, color=:steelblue)
    data = hasproperty(v, :data) ? v.data : v
    if kind == :hist
        hist!(ax, data; bins, color)
    else
        lines!(ax, 1:length(data), sort(data); color)
    end
    if hasproperty(v, :unit)
        unit_val = getfield(v, :unit)
        if unit_val !== nothing && !(unit_val isa AbstractString && isempty(unit_val))
            ax.xlabel = unit_val
        end
    end
    if !isempty(title)
        ax.title[] = title
    end
    ax
end

function dist_plot_compare(make::Function, N; title="", color=:steelblue)
    d_nr = make()
    d_r = make()
    sample!(d_nr, N; random=false)
    sample!(d_r, N; random=true)
    fig = Figure(size=(800, 320))
    a = Axis(fig[1, 1], title=isempty(title) ? "non-random (quantiles)" : "$(title) — non-random")
    b = Axis(fig[1, 2], title=isempty(title) ? "random (samples)" : "$(title) — random")
    dist_plot!(a, d_nr; kind=:line, color)
    dist_plot!(b, d_r; kind=:line, color)
    fig
end

function arrow_arc_deg!(ax, origin, radius, start_angle_deg, stop_angle_deg;
    linewidth=1, color=:black, flip_arrow=false, linestyle=:dot, startarrow=false, space=:relative)
    deg2rad(θ_deg) = θ_deg * π / 180
    rad_start = deg2rad(90 - start_angle_deg)
    rad_stop = deg2rad(90 - stop_angle_deg)
    arc!(ax, origin, radius, rad_start, rad_stop, linewidth=linewidth, color=color; linestyle=linestyle, space)
    point_on_circle_deg(θ_deg) = origin .+ radius * Point2f(
        cos(deg2rad(90 - θ_deg)),
        sin(deg2rad(90 - θ_deg))
    )
    start_dir = Point2f(
        cos(rad_start + π / 2 + (flip_arrow ? π / 2 : 0)),
        sin(rad_start + π / 2 + (flip_arrow ? π / 2 : 0))
    )
    end_dir = Point2f(
        cos(rad_stop - π / 2 + (flip_arrow ? π : 0)),
        sin(rad_stop - π / 2 + (flip_arrow ? π : 0))
    )
    dx = 0.001
    startarrow ? arrows2d!(
        ax,
        [point_on_circle_deg(start_angle_deg)[1]],
        [point_on_circle_deg(start_angle_deg)[2]],
        [start_dir[1]] .* dx,
        [start_dir[2]] .* dx,
        color=color,
        shaftwidth=linewidth
    ) : nothing
    arrows2d!(
        ax,
        [point_on_circle_deg(stop_angle_deg)[1]],
        [point_on_circle_deg(stop_angle_deg)[2]],
        [end_dir[1]] .* dx,
        [end_dir[2]] .* dx,
        color=color,
        shaftwidth=linewidth
    )
end

# --- helpers ---------------------------------------------------------------
function _ranks(v::AbstractVector)
    p = sortperm(v)
    r = similar(v, Float64)
    n = length(v)
    i = 1
    while i <= n
        j = i
        @inbounds while j < n && v[p[j+1]] == v[p[i]]
            j += 1
        end
        avg = (i + j) / 2
        @inbounds for k in i:j
            r[p[k]] = avg
        end
        i = j + 1
    end
    return r
end

function welch_t(x::AbstractVector, y::AbstractVector)
    nx, ny = length(x), length(y)
    μx, μy = mean(x), mean(y)
    sx2, sy2 = var(x), var(y)
    denom = sqrt(sx2 / nx + sy2 / ny)
    return iszero(denom) ? 0.0 : (μx - μy) / denom
end

corr_significant(r::Real, n::Int) = begin
    r2 = r * r
    if n <= 3 || r2 ≥ 1
        false
    else
        t = abs(r) * sqrt((n - 2) / max(1e-12, 1 - r2))
        t > 2
    end
end

_color_from_r(cm, r::Float64) = begin
    t = clamp((r + 1) / 2, 0.0, 1.0)   # -1→0, 0→0.5, 1→1
    cm[clamp(1 + round(Int, t * (length(cm) - 1)), 1, length(cm))]
end

_coerce_labels(vars::Vector{Symbol}, labels) = labels === nothing ?
                                               string.(vars) : String.(map(identity, labels))

# ----------------------------------------------------------------------------
"""
distribution_plot(
    data, vars;
    labels=nothing, corr=:pearson,
    cellsize=(120,120), markersize=3, alpha=0.6,
    cmap=:coolwarm, reverse_cmap=false,
    dep_range=(1:4, 5:8)
)

- Upper triangle: blank (no axes).
- Diagonal: KDE (darker band) or ♂/♀ bars for `:gender`.
- Lower triangle:
  * if x-var is `:gender`: violin; pane color uses red↔blue (point-biserial r) when Welch |t|>2, else darkgray
  * else: scatter with black points; if corr significant (|t(r)|>2) set axis background by signed r (red↔blue) and show bold **white r²** (upper-left) with **glow**
- Headers: left row labels (bold, rotated); bottom column labels (bold).
- **Gaps**: `colgap!(fig.layout, 8)` and `rowgap!(fig.layout, 6)`.
- **Ticks**: show **y ticks only** on the **left column**; show **x ticks only** on the **bottom row**.
  All other ticks are hidden (but **grids stay visible everywhere**).
- Dependency plot: always added at `fig[dep_range...]`, with `hidespines!` and `hidedecorations!(depplot)`.

Max ticks: at most 3 per axis (LinearTicks(3)).
Returns `fig, depplot`.
"""
function distribution_plot(
    data,
    vars::Vector{Symbol};
    labels=nothing,
    corr::Symbol=:pearson,
    cellsize=(120, 120),
    markersize=3,
    alpha=0.6,
    cmap=:coolwarm,
    reverse_cmap::Bool=false,
    dep_range=(1:4, 5:8)
)
    @assert corr in (:pearson, :spearman)

    cols = [Float64.(getproperty(data, s)) for s in vars]
    n = length(first(cols))
    @assert all(length(c) == n for c in cols)

    lab = _coerce_labels(vars, labels)
    @assert length(lab) == length(vars)

    has_gender = :gender in vars
    g = has_gender ? round.(Int, Float64.(getproperty(data, :gender))) : fill(-1, n) # expect 0/1
    gfloat = has_gender ? Float64.(g) : zeros(n)
    male_label, female_label = "♂", "♀"

    X = hcat(cols...)
    p = length(vars)

    C = if corr == :pearson
        cor(X)
    else
        R = hcat([_ranks(view(X, :, j)) for j in 1:p]...)
        cor(R)
    end

    # Figure (extra height for bottom labels)
    total_size = (cellsize[1] * p, cellsize[2] * p + 28)
    fig = Figure(size=total_size, fontsize=10)


    # Left row labels (0th col)
    for i in 1:p
        fig[i, 0] = Label(fig, lab[i]; halign=:right, valign=:center,
            fontsize=12, font=:bold, rotation=pi / 2, tellheight=false)
    end
    # Bottom column labels (row p+1)
    for j in 1:p
        fig[p+1, j] = Label(fig, lab[j]; halign=:center, valign=:top,
            fontsize=12, font=:bold, tellwidth=false)
    end

    # Colormap for signed r
    base_cm = to_colormap(cmap)
    cm = reverse_cmap ? reverse(base_cm) : base_cm

    # Axes only for diagonal & lower
    axes = Array{Union{Axis,Nothing}}(undef, p, p)
    make_axis() = begin
        ax = Axis(fig;
            xticks=LinearTicks(3),
            yticks=LinearTicks(3),
        )
        hidespines!(ax)
        ax.xlabelvisible = false
        ax.ylabelvisible = false
        ax.xgridvisible = true
        ax.ygridvisible = true
        ax
    end
    for i in 1:p, j in 1:p
        if i == j || i > j
            ax = make_axis()
            fig[i, j] = ax
            axes[i, j] = ax
        else
            axes[i, j] = nothing  # upper stays empty
        end
    end

    # Limits
    lims = [(minimum(view(X, :, j)), maximum(view(X, :, j))) for j in 1:p]

    # Gender violin helper
    function draw_gender_violin!(ax::Axis, yvals::AbstractVector, gvec::AbstractVector{<:Integer};
        fillcolor=:darkgray)
        y_m = yvals[gvec.==0]
        y_f = yvals[gvec.==1]
        x = vcat(fill(1, length(y_m)), fill(2, length(y_f)))
        y = vcat(y_m, y_f)
        xlims!(ax, 0.5, 2.5)
        violin!(ax, x, y; width=0.8, show_median=true, color=fillcolor)
        ax.xticks = (1:2, [male_label, female_label])
    end

    for i in 1:p, j in 1:p
        ax = axes[i, j]
        ax === nothing && continue

        xi = view(X, :, j)
        yi = view(X, :, i)

        if i == j
            # Diagonal
            if has_gender && vars[i] == :gender
                counts = (sum(g .== 0), sum(g .== 1))
                x = [1, 2]
                y = collect(counts)
                xlims!(ax, 0.5, 2.5)
                ylims!(ax, 0, maximum(y) * 1.15)
                barplot!(ax, x, y; color=:darkgray)
                ax.xticks = (1:2, [male_label, female_label])
            else
                xlims!(ax, lims[j]...)
                kd = kde(xi)
                ylims!(ax, 0, maximum(kd.density) * 1.05)
                lines!(ax, kd.x, kd.density; color=:gray20)
                band!(ax, kd.x, zero.(kd.density), kd.density; color=:gray35, transparency=true, alpha=0.5)
            end
        else
            # Lower triangle
            if has_gender && vars[j] == :gender
                ylims!(ax, lims[i]...)
                tval = welch_t(yi[g.==0], yi[g.==1])
                rpb = cor(gfloat, yi)
                vcolor = abs(tval) > 2 ? _color_from_r(cm, rpb) : :darkgray
                draw_gender_violin!(ax, yi, g; fillcolor=vcolor)
            else
                xlims!(ax, lims[j]...)
                ylims!(ax, lims[i]...)
                r = C[i, j]
                if corr_significant(r, n)
                    ax.backgroundcolor = _color_from_r(cm, r)
                    scatter!(ax, xi, yi; markersize=markersize, color=:black, transparency=true, alpha=alpha)
                    text!(ax, 0.065, 0.98, text=@sprintf("%.2f", r * r),
                        space=:relative, align=(:left, :top),
                        fontsize=12, color=:white, font=:bold,
                        glowcolor=:black, glowwidth=6)
                else
                    scatter!(ax, xi, yi; markersize=markersize, color=:black, transparency=true, alpha=alpha)
                end
            end
        end

        # --- Ticks & grids policy per panel ---------------------------------
        # keep grids on every panel
        ax.xgridvisible = true
        ax.ygridvisible = true

        # Check if this panel has gender-specific custom ticks
        is_gender_violin = has_gender && ((i != j && vars[j] == :gender) || (i == j && vars[i] == :gender))

        # show x ticks only on bottom row, hide elsewhere (preserve grids)
        if i == p
            # Don't override custom gender ticks
            if !is_gender_violin
                ax.xticks = LinearTicks(3)
            end
        else
            hidexdecorations!(ax; label=false, ticks=false, grid=false)
        end
        # show y ticks only on left column, hide elsewhere (preserve grids)
        if j == 1
            # Don't override custom gender ticks
            if !is_gender_violin
                ax.yticks = LinearTicks(3)
            end
        else
            hideydecorations!(ax; label=false, ticks=false, grid=false)
        end
    end

    # Dependency plot: strip everything
    depplot = Axis(fig;
        xticks=LinearTicks(3),
        yticks=LinearTicks(3),
        title="Causal Dependency (DAG)",
        titlesize=16,
        titlefont=:bold
    )
    fig[dep_range[1], dep_range[2]] = depplot
    hidespines!(depplot)
    hidedecorations!(depplot)  # remove ticks, labels, grid, etc.
    dependency_graph_plot!(depplot, data)
    colgap!(fig.layout, 8)
    rowgap!(fig.layout, 6)
    return fig
end