using CairoMakie
using Colors
using ColorSchemes
using LinearAlgebra

const _Γ = Γ
const _Φ = Φ
const _sim = sim
const _dependency_graph = dependency_graph
const _incomes = incomes

function Γ_plot!(axis, sol; color=:darkorange, linewidth=3, t=0.0)
    y = range(0.0, stop=1.0, length=100)
    lines!(axis, y, _Γ.(y, Ref(sol.prob.p), x=sol.u[end-1]; t); color, linewidth)
end

function Φ_plot!(axis, sol; color=:darkorange, linewidth=3, t=0.0)
    y = range(0.0, stop=1.0, length=100)
    lines!(axis, y, Φ.(y, Ref(sol.prob.p); t); color, linewidth)
end

function attractor_plot!(axis, sol; color=:darkorange, markersize=15, marker=:circle)
    N = sol.prob.p.N
    scatter!(axis, [sol[N+1, end-2]], [sum(sol[1:N, end-2] ./ sol.prob.p.μ(sol.u[end-2], sol.prob.p, sol.t[end-2]) ./ N)];
        color, markersize, marker)
end

function trajectory_plot!(axis, sol; color=:darkorange, startcolor=:lightgray, linewidth=2)
    scenario = sol.prob.p
    lines!(axis,
        [u[scenario.N+1] for u in sol.u[1:end-2]],
        [sum(u[1:scenario.N] ./ scenario.μ(u, scenario, sol.t[i])) / scenario.N for (i, u) in enumerate(sol.u[1:end-2])];
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
        lines!(axis, y, _Φ.(1 .- (1 - scenario.regulation) ./ Y, Ref(scenario)); color, linewidth, linestyle)
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
    g = _dependency_graph(s)
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
            return "Incentives"
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
            fontsize=fontsize)
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
        oa = change(scenario, policy="Open Access", γ=γ, μ=μ, regulate=regulate, ϕ=ϕ)
        oasol = _sim(oa)
        lines!(axis, y, _Γ.(y, Ref(oa), x=sol.u[end-1]), color=open_access_color, linewidth=3)
        lines!(axis, y, _Φ.(y, Ref(oa)), color=open_access_color, linewidth=1)
    end
    lines!(axis, y, _Γ.(y, Ref(scenario), x=sol.u[end-1]; t), color=incentive_line_color, linewidth=3)
    lines!(axis, y, _Φ.(y, Ref(scenario); t), color=impact_line_color, linewidth=1)
    if show_target && haskey(scenario, :policy_target)
        Y = scenario.policy_target == :effort ? ones(length(y)) : y
        lines!(axis, y, _Φ.(1 .- (1 - scenario.regulation) ./ Y, Ref(scenario)), color=:darkorange, linestyle=:dot)
    end
    if show_trajectory
        lines!(axis,
            [u[scenario.N+1] for u in sol.u[1:end-2]],
            [sum(u[1:scenario.N] ./ scenario.μ(u, scenario, sol.t[i])) / scenario.N for (i, u) in enumerate(sol.u[1:end-2])],
            color=scenario.policy == "Development" ? sol.t[1:end-2] : trajectory_color,
            linestyle=:dot,
            colormap=cgrad([:lightgray, :darkorange], [0.0, 0.5, 1.0]))
    end
    scatter!(axis, [sol[N+1, end-2]], [sum(sol[1:N, end-2] ./ scenario.μ(sol.u[end-2], scenario, sol.t[end-2]) ./ N)], color=:black, markersize=10)
end

function phase_plot(sol)
    f = Figure()
    a = Axis(f[1, 1])
    phase_plot!(a, sol)
    f
end

function incomes_plot!(ax, sol; order=false, sort_by_incentives=false, color=:darkorange, dimensional::Bool=false, resource_incomes=true)
    inc = _incomes(sol)
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

