using CairoMakie
using Colors
using ColorSchemes
using LinearAlgebra

# Bring core helpers into scope
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
    lines!(axis, y, _Φ.(y, Ref(sol.prob.p); t); color, linewidth)
end

function attractor_plot!(axis, sol; color=:darkorange, markersize=15, marker=:circle)
    N = sol.prob.p.N
    scatter!(axis, [sol[N+1, end-2]], [sum(sol[1:N, end-2] ./ sol.prob.p.μ(sol.u[end-2], sol.prob.p, sol.t[end-2]) ./ N)];
            color, markersize, marker)
end

function trajecory_plot!(axis, sol; color=:darkorange, startcolor=:lightgray, linewidth=2)
    scenario = sol.prob.p
    lines!(axis,
        [u[scenario.N+1] for u in sol.u[1:end-2]],
        [sum(u[1:scenario.N] ./ scenario.μ(u, scenario, sol.t[i])) / scenario.N for (i, u) in enumerate(sol.u[1:end-2])];
        color, linestyle=:dot, colormap=cgrad([startcolor, color], [0.0, 0.5, 1.0]), linewidth)
end

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
    g = _dependency_graph(s)
    # Build reverse adjacency: dep -> [dependents]
    children = Dict{Symbol, Vector{Symbol}}(k => Symbol[] for k in g.nodes)
    for (k, deps) in g.edges
        for d in deps
            push!(children[d], k)
        end
    end
    # Compute levels
    level = Dict{Symbol, Int}()
    for k in g.order
        deps = get(g.edges, k, Symbol[])
        level[k] = isempty(deps) ? 0 : maximum(get(level, d, 0) + 1 for d in deps)
    end
    levels = Dict{Int, Vector{Symbol}}()
    for k in g.nodes
        l = level[k]
        get!(levels, l, Symbol[])
        push!(levels[l], k)
    end
    pos = Dict{Symbol, Point2f}()
    max_level = maximum(values(level))
    for (l, ks) in levels
        n = length(ks)
        xs = n == 1 ? [0.5] : collect(range(0.1, 0.9, length=n))
        ys = fill(1.0 - (max_level == 0 ? 0.5 : l / (max_level + 0.5)), n)
        for (i, k) in enumerate(ks)
            pos[k] = Point2f(xs[i], ys[i])
        end
    end
    fig = Figure(size=figsize)
    ax = Axis(fig[1, 1])
    hidespines!(ax)
    hidexdecorations!(ax, grid=false, ticks=false, ticklabels=false)
    hideydecorations!(ax, grid=false, ticks=false, ticklabels=false)
    # Edges
    r = 0.035
    for (k, deps) in g.edges
        for d in deps
            p1 = pos[d]; p2 = pos[k]
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
    # Labels only
    for (k, p) in pos
        text!(ax, p[1], p[2], text=String(k), align=(:center, :center), color=:black, fontsize)
    end
    fig
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

function incomes_plot!(ax, sol; order=false, color=:darkorange, dimensional::Bool=false, resource_incomes=true)
    inc = _incomes(sol)
    res = inc.resource; wage = inc.wages; trd = inc.trade; total = inc.total
    idx = order ? sortperm(total) : eachindex(total)
    barplot!(ax, (res[idx] .+ wage[idx]), color=color, alpha=1.0, offset=trd[idx])
    barplot!(ax, trd[idx], color=color)
    barplot!(ax, trd[idx], color=HSLA(0, 0, 0, 0.2))
end

# --- distribution visualization helpers ---

"""
    dist_plot!(ax, v; title="", kind=:line, bins=30, color=:steelblue)

Visualize a sampled distribution `v` (either a `Dist` or a `Vector`).
- `kind=:line` plots the sorted values as a line.
- `kind=:hist` plots a histogram with `bins`.
"""
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

"""
    dist_plot_compare(v::Function, N; kwargs...)

Convenience function: given a zero-arg constructor `v()` that returns a `Dist`
with parameters set (min/max/mean/...), produce a side-by-side comparison of
non-random (quantiles) vs random sampling for length `N`.
Returns a `Figure`.
"""
function dist_plot_compare(make::Function, N; title="", color=:steelblue)
    d_nr = make()
    d_r  = make()
    sample!(d_nr, N; random=false)
    sample!(d_r,  N; random=true)
    fig = Figure(size=(800, 320))
    a = Axis(fig[1,1], title = isempty(title) ? "non-random (quantiles)" : "$(title) — non-random")
    b = Axis(fig[1,2], title = isempty(title) ? "random (samples)" : "$(title) — random")
    dist_plot!(a, d_nr; kind=:line, color)
    dist_plot!(b, d_r;  kind=:line, color)
    fig
end
