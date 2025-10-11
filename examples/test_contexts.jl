T = (
    N=200,
    health=dist(mean=0, sigma=2.0, distribution=Normal, dependency_fun="1/(1+exp(-2-independent))"),#1-max(0.0,independent)
    gender=dist(mean=0.5, distribution=Bernoulli, random=true),
    parental=dist(min=0.1, max=1.0, distribution=LogNormal),
    time=dist(dependency_fun="health*(1-gender*0.5)*independent", min=0, max=1),
    efficiency=dist(min=0.015, max=0.2, dependency_fun="1*parental*(1-gender*0.2)*independent", normalize=false),
    opportunities=dist(min=0.1, max=1.6, distribution=LogNormal, dependency_fun="0.02*parental*(1-gender*0.5)*independent"),
    K=2.0,
    ū=dist(min=-0.1, max=0.1, dependency_fun="time*efficiency"),
    w̃=dist(min=-0.1, max=0.1, dependency_fun="(opportunities ./ efficiency) .+ independent"),
    α=dist(min=0.1, max=0.1, distribution=Uniform) #fill(0.1,100)#
)
sample!(T, random=true)
male = :steelblue
female = :pink
set_theme!(Theme(palette=(; color=[female, male])))


f = Figure(size=(800, 1000))



health_ax = Axis(f[1, 1], xlabel="Health")
parental_ax = Axis(f[1, 3], xlabel="""Parental incomes (\$)""")
dep_ax = Axis(f[1, 2])

opportunities_ax = Axis(f[2, 3], xlabel="""Alternative Opportunities (\$)""")
efficiency_ax = Axis(f[2, 2], xlabel="Efficiency (kg/hour)")
time_ax = Axis(f[2, 1], xlabel="Harvest Time (hours)")

#incentives_ax = Axis(f[3, 1], title="Incentives")
#impact_ax = Axis(f[3, 3], title="Impact")
OA_ax = Axis(f[3, 1], title="Open Access")
URp_ax = Axis(f[3, 2], title="Assigned Use Rights low")
URr_ax = Axis(f[3, 3], title="Assigned Use Rights high")

OA_incomes_ax = Axis(f[4, 1], height=100)
UR_incomes_ax = Axis(f[4, 2], height=100)
UR_incomes_ax = Axis(f[4, 3], height=100)

TUR_ax = Axis(f[5, 1], title="Tradable Use Rights all")
TURh_ax = Axis(f[5, 2], title="Tradable Use Rights historical")
PA_ax = Axis(f[5, 3], title="Protected Area")

[hidedecorations!(ax) for ax in [dep_ax]]
[hidedecorations!(ax, grid=false) for ax in [OA_ax, URp_ax, URr_ax, TUR_ax, TURh_ax, PA_ax]]
[hidespines!(ax) for ax in [dep_ax, health_ax, parental_ax, opportunities_ax, efficiency_ax, time_ax, OA_ax, URp_ax, URr_ax, TUR_ax, TURh_ax, PA_ax, OA_incomes_ax]]
xlims!(dep_ax, -0.1, 1.1)

dependency_graph_plot!(dep_ax, T)
scatter!(opportunities_ax, ecdf(T.opportunities[findall(T.gender .== 1)]), color=female)
scatter!(opportunities_ax, ecdf(T.opportunities[findall(T.gender .== 0)]), color=male)
lines!(opportunities_ax, fill(median(T.opportunities[findall(T.gender .== 1)]), 2), [0, 1])
lines!(opportunities_ax, fill(median(T.opportunities[findall(T.gender .== 0)]), 2), [0, 1])

#scatter!(incentives_ax, ecdf(T.w̃), color=[g == 1 ? female : male for g in T.gender])
#scatter!(impact_ax, ecdf(T.ū), color=[g == 1 ? female : male for g in T.gender])
scatter!(efficiency_ax, ecdf(T.efficiency[findall(T.gender .== 1)]), color=female)
scatter!(efficiency_ax, ecdf(T.efficiency[findall(T.gender .== 0)]), color=male)

scatter!(time_ax, ecdf(T.time[findall(T.gender .== 1)]), color=female)
scatter!(time_ax, ecdf(T.time[findall(T.gender .== 0)]), color=male)

health = deepcopy(T.health)
op = deepcopy(T.opportunities)
#sample!(op, 100, context=NamedTuple())
sample!(health, 100, context=NamedTuple())
d = diff(sort(health)) .^ -1
d = d ./ maximum(d)
scatter!(health_ax, ecdf(T.health), color=:gray)
#scatter!(health_ax, sort(health)[2:end], d, color=:gray)
scatter!(parental_ax, ecdf(T.parental), color=:gray)
phase_plot!(OA_ax, sim(scenario(T)))
phase_plot!(URp_ax, sim(scenario(T)))
phase_plot!(URr_ax, sim(scenario(T)))

phase_plot!(TUR_ax, sim(scenario(T)))
phase_plot!(TURh_ax, sim(scenario(T)))
phase_plot!(PA_ax, sim(scenario(T)))

incomes_plot!(OA_incomes_ax, sim(scenario(T)), order=true, sort_by_incentives=true)

Label(f[1, 0], "Proximal factors", rotation=pi / 2, tellheight=false, font=:bold)
Label(f[2, 0], "Secondary factors", rotation=pi / 2, tellheight=false, font=:bold)
Label(f[3:4, 0], "Best Outcomes of policies", rotation=pi / 2, tellheight=false, font=:bold)
f

#=
using CairoMakie
using Statistics
using KernelDensity
using Printf

# -- Spearman ranks (average ranks with ties), no external deps ----------------
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

# Welch t; treat |t| > 2 as “significant” (quick heuristic)
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

# Map r ∈ [-1,1] to a diverging colormap
function _color_from_r(cm, r::Float64)
    t = clamp((r + 1) / 2, 0.0, 1.0) # -1→0, 0→0.5, 1→1
    cm[clamp(1 + round(Int, t * (length(cm) - 1)), 1, length(cm))]
end

"""
paircorrplot(data, vars; names=nothing, corr=:pearson, upper=:both,
             cellsize=(120,120), markersize=3, alpha=0.6,
             cmap=:RdBu, reverse_cmap=true)

- Lower triangle:
    * If x-variable is `:gender` → violin of row var (y) split by gender (♂=0, ♀=1), categorical x.
      Color **green** if Welch |t|>2, else **darkgray**.
    * Else → scatter; color **green** if correlation significant, else **darkgray**.
- Diagonal:
    * KDE for numeric vars; for `:gender` → two-bar count (♂/♀), no KDE.
- Upper triangle:
    * Heat (diverging cmap with signed mapping) and/or big numeric correlation (no “r =”).

Styling:
- Grids ON for all axes, but we **preserve** grids specifically on scatter (lower-triangle) via `grid=false` in hide calls.
- Spines hidden everywhere.
- Axis labels hidden; instead:
  * Top headers (0th row) via `Label(...; tellwidth=false)`
  * Left headers (0th col) via `Label(...; rotation=pi/2, tellheight=false)`
- Ticks only on bottom row (x) and left column (y).
"""
function paircorrplot(data, vars::AbstractVector{Symbol};
    names=nothing, corr::Symbol=:pearson, upper::Symbol=:both,
    cellsize=(120, 120), markersize=3, alpha=0.6,
    cmap=:RdBu, reverse_cmap::Bool=true)

    @assert corr in (:pearson, :spearman)
    @assert upper in (:text, :heat, :both)

    cols = [Float64.(getproperty(data, s)) for s in vars]
    n = length(first(cols))
    @assert all(length(c) == n for c in cols)

    labels = isnothing(names) ? string.(vars) : String.(names)
    @assert length(labels) == length(vars)

    has_gender = :gender in vars
    g = has_gender ? round.(Int, Float64.(getproperty(data, :gender))) : fill(-1, n) # expect 0/1
    male_label, female_label = "♂", "♀"

    X = hcat(cols...)
    p = length(vars)

    C = if corr == :pearson
        cor(X)
    else
        R = hcat([_ranks(view(X, :, j)) for j in 1:p]...)
        cor(R)
    end

    # Figure & grid with header bands
    total_size = (cellsize[1] * p, cellsize[2] * p + 28)  # room for top headers
    fig = Figure(size=total_size, fontsize=10)
    grid = fig[1, 1] = GridLayout()

    # Top column headers (0th row)
    for j in 1:p
        grid[0, j] = Label(fig, labels[j]; halign=:center, valign=:bottom, fontsize=12, font=:bold, tellwidth=false)
    end
    # Left row headers (0th col)
    for i in 1:p
        grid[i, 0] = Label(fig, labels[i]; halign=:right, valign=:center, fontsize=12, font=:bold, rotation=pi / 2, tellheight=false)
    end

    # Axes
    axes = [Axis(fig) for _ in 1:p, _ in 1:p]
    for i in 1:p, j in 1:p
        ax = axes[i, j]
        grid[i, j] = ax
        hidespines!(ax)
        ax.xlabelvisible = false
        ax.ylabelvisible = false
        ax.xgridvisible = true
        ax.ygridvisible = true
        # We’ll manage ticks & grid-hiding per cell below.
    end

    # Variable limits
    lims = [(minimum(view(X, :, j)), maximum(view(X, :, j))) for j in 1:p]

    # Colormap
    base_cm = to_colormap(cmap)
    cm = reverse_cmap ? reverse(base_cm) : base_cm

    # Gender violin helper
    function draw_gender_violin!(ax::Axis, yvals::AbstractVector, gvec::AbstractVector{<:Integer}; color_sym=:darkgray)
        y_m = yvals[gvec.==0]
        y_f = yvals[gvec.==1]
        x = vcat(fill(1, length(y_m)), fill(2, length(y_f)))
        y = vcat(y_m, y_f)
        xlims!(ax, 0.5, 2.5)
        violin!(ax, x, y; width=0.8, show_median=true, color=color_sym)
        ax.xticks = (1:2, [male_label, female_label])
    end

    for i in 1:p, j in 1:p
        ax = axes[i, j]
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
                lines!(ax, kd.x, kd.density; color=:darkgray)
                band!(ax, kd.x, zero.(similar(kd.density)), kd.density; transparency=true, alpha=0.2)
            end
            # Diagonal: hide ticks except on bottom & left, grids can remain hidden (default)
            if i != p
                hidexdecorations!(ax; label=false, ticks=false)
            end
            if j != 1
                hideydecorations!(ax; label=false, ticks=false)
            end

        elseif i > j
            # Lower triangle (scatter/violin) — we PRESERVE grids via grid=false in hide calls
            if has_gender && vars[j] == :gender
                ylims!(ax, lims[i]...)
                tval = welch_t(yi[g.==0], yi[g.==1])
                col = abs(tval) > 2 ? :green : :darkgray
                draw_gender_violin!(ax, yi, g; color_sym=col)
            else
                xlims!(ax, lims[j]...)
                ylims!(ax, lims[i]...)
                r = C[i, j]
                col = corr_significant(r, n) ? :green : :darkgray
                scatter!(ax, xi, yi; markersize=markersize, color=col, transparency=true, alpha=alpha)
            end
            # Keep grids visible: grid=false in hide calls below
            if i != p
                hidexdecorations!(ax; label=false, ticks=false, grid=false)
            end
            if j != 1
                hideydecorations!(ax; label=false, ticks=false, grid=false)
            end

        else
            # Upper triangle (heat/text) — grids can be hidden (default)
            xlims!(ax, 0, 1)
            ylims!(ax, 0, 1)
            r = C[i, j]
            if upper == :heat || upper == :both
                poly!(ax, Rect(0, 0, 1, 1); color=_color_from_r(cm, r), space=:relative)
            end
            if upper == :text || upper == :both
                text!(ax, 0.5, 0.5, text=@sprintf("%.2f", r),
                    align=(:center, :center), space=:relative, fontsize=14,
                    color=(abs(r) > 0.5 ? :white : :black))
            end
            if i != p
                hidexdecorations!(ax; label=false, ticks=false)
            end
            if j != 1
                hideydecorations!(ax; label=false, ticks=false)
            end
        end
    end

    return fig
end


# ------------------------------------------------------------------------------
"""
pairgrid_blank_upper(data, vars; names=nothing, corr=:pearson,
                     cellsize=(120,120), markersize=3, alpha=0.6)

A pair grid that:
- **Upper-right triangle**: left completely **blank**.
- **Diagonal**: KDE for numeric vars; if the var is `:gender` → two-bar count (♂/♀).
- **Lower triangle**:
    * If x-variable is `:gender` → **violin** of row variable by gender (categorical x: ♂/♀).
      Color **green** if Welch |t|>2, else **darkgray**.
    * Else → **scatter** colored **green** if correlation significant (|t(r)|>2), else **darkgray**.

Styling:
- Grids ON for all axes; for lower-triangle we preserve grids via `grid=false` in hide calls.
- Spines hidden everywhere.
- Ticks only on bottom row (x) and left column (y).
- Axis labels hidden; instead header **Labels**:
  * Top (0th row): `Label(...; tellwidth=false)`
  * Left (0th col): `Label(...; rotation=pi/2, tellheight=false)`
"""
function pairgrid_blank_upper(data, vars::AbstractVector{Symbol};
    names=nothing, corr::Symbol=:pearson,
    cellsize=(120, 120), markersize=3, alpha=0.6)

    @assert corr in (:pearson, :spearman)

    cols = [Float64.(getproperty(data, s)) for s in vars]
    n = length(first(cols))
    @assert all(length(c) == n for c in cols)

    labels = isnothing(names) ? string.(vars) : String.(names)
    @assert length(labels) == length(vars)

    has_gender = :gender in vars
    g = has_gender ? round.(Int, Float64.(getproperty(data, :gender))) : fill(-1, n) # expect 0/1
    male_label, female_label = "♂", "♀"

    X = hcat(cols...)
    p = length(vars)

    C = if corr == :pearson
        cor(X)
    else
        R = hcat([_ranks(view(X, :, j)) for j in 1:p]...)
        cor(R)
    end

    # Figure/grid with header bands
    total_size = (cellsize[1] * p, cellsize[2] * p + 28)
    fig = Figure(size=total_size, fontsize=10)
    grid = fig[1, 1] = GridLayout()

    # Top headers
    for j in 1:p
        grid[length(vars)+1, j] = Label(fig, labels[j]; halign=:center, valign=:bottom,
            fontsize=12, font=:bold, tellwidth=false)
    end
    # Left headers
    for i in 1:p
        grid[i, 0] = Label(fig, labels[i]; halign=:right, valign=:center,
            fontsize=12, font=:bold, rotation=pi / 2, tellheight=false)
    end

    # Axes
    axes = [Axis(fig) for _ in 1:p, _ in 1:p]
    for i in 1:p, j in 1:p
        ax = axes[i, j]
        grid[i, j] = ax
        hidespines!(ax)
        ax.xlabelvisible = false
        ax.ylabelvisible = false
        ax.xgridvisible = true
        ax.ygridvisible = true
    end

    # Limits
    lims = [(minimum(view(X, :, j)), maximum(view(X, :, j))) for j in 1:p]

    # Gender violin helper
    function draw_gender_violin!(ax::Axis, yvals::AbstractVector, gvec::AbstractVector{<:Integer}; color_sym=:darkgray)
        y_m = yvals[gvec.==0]
        y_f = yvals[gvec.==1]
        x = vcat(fill(1, length(y_m)), fill(2, length(y_f)))
        y = vcat(y_m, y_f)
        xlims!(ax, 0.5, 2.5)
        violin!(ax, x, y; width=0.8, show_median=true, color=color_sym)
        ax.xticks = (1:2, [male_label, female_label])
    end

    for i in 1:p, j in 1:p
        ax = axes[i, j]
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
                lines!(ax, kd.x, kd.density; color=:darkgray)
                band!(ax, kd.x, zero.(kd.density), kd.density; transparency=true, alpha=0.2)
            end
            # Diagonal ticks policy
            if i != p
                hidexdecorations!(ax; label=false, ticks=false)
            end
            if j != 1
                hideydecorations!(ax; label=false, ticks=false)
            end

        elseif i > j
            # Lower triangle (scatter/violin) — PRESERVE grids via grid=false in hide calls
            if has_gender && vars[j] == :gender
                ylims!(ax, lims[i]...)
                tval = welch_t(yi[g.==0], yi[g.==1])
                col = abs(tval) > 2 ? :green : :darkgray
                draw_gender_violin!(ax, yi, g; color_sym=col)
            else
                xlims!(ax, lims[j]...)
                ylims!(ax, lims[i]...)
                r = C[i, j]
                col = corr_significant(r, n) ? :green : :darkgray
                scatter!(ax, xi, yi; markersize=markersize, color=col, transparency=true, alpha=alpha)
            end
            if i != p
                hidexdecorations!(ax; label=false, ticks=false, grid=false)
            end
            if j != 1
                hideydecorations!(ax; label=false, ticks=false, grid=false)
            end

        else
            # Upper triangle: **blank** — keep axis clean
            xlims!(ax, 0, 1)
            ylims!(ax, 0, 1)
            # Hide ticks/labels; grid can be hidden (no content)
            if i != p
                hidexdecorations!(ax; label=false, ticks=false)
            end
            if j != 1
                hideydecorations!(ax; label=false, ticks=false)
            end
        end
    end

    return fig
end

#fig = paircorrplot(T, vars; names=names, corr=:spearman, upper=:both, cellsize=(90,90), markersize=5, cmap=:coolwarm, reverse_cmap=false)
=#



using CairoMakie
using Statistics
using KernelDensity
using Printf
using Makie: LinearTicks  # for max tick count

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
pairgrid_blank_upper_redblue_with_dep(
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
function pairgrid_blank_upper_redblue_with_dep(
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



labels = ["Gender", "Health", "Parental", "Time", "Efficiency", "Opport.", "Impact", "Incentive"]
vars = [:gender, :health, :parental, :time, :efficiency, :opportunities, :ū, :w̃]


fig = pairgrid_blank_upper_redblue_with_dep(
    T, vars; labels=labels,
    corr=:spearman,
    cellsize=(90, 90), markersize=3,
    cmap=:coolwarm, reverse_cmap=false,
    dep_range=(1:4, 5:8)   # placed at fig[1:4, 5:8]
)

save("pairgrid_blank_upper_redblue_with_dep.png", fig)
fig
