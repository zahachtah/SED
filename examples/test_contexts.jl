using StatsBase: ecdf, median
using KernelDensity
using Statistics
using Printf



using CairoMakie
using Statistics
using KernelDensity
using Printf
using Makie: LinearTicks  # for max tick count

T = (
    N=200,
    health=dist(mean=0, sigma=2.0, distribution=Normal, dependency_fun="1/(1+exp(-2-independent))"),#1-max(0.0,independent)
    gender=dist(mean=0.5, distribution=Bernoulli, random=true),
    parental=dist(min=0.1, max=1.0, distribution=LogNormal),
    time=dist(dependency_fun="health*(1-gender*0.5)*independent", min=0, max=1),
    efficiency=dist(min=0.015, max=0.2, dependency_fun="1*parental*(1-gender*0.2)*independent", normalize=false),
    AIO=dist(min=0.1, max=1.6, distribution=LogNormal, dependency_fun="0.02*parental*(1-gender*0.3)*independent"),
    K=2.0,
    ū=dist(min=-0.1, max=0.1, dependency_fun="time*efficiency"),
    w̃=dist(min=-0.1, max=0.1, dependency_fun="(AIO ./ efficiency) .+ independent"),
    α=dist(min=0.1, max=0.1, distribution=Uniform) #fill(0.1,100)#
)

# Zanzibar (ZNZ): calibrated to:
#   time gap ≈ 60% (women vs men: 2–3h vs 6–8h),
#   efficiency gap ≈ 65% (women ≈ 35% of men),
#   parental status ~ low-income right-skew (use LogNormal w/ min/max, no meanlog/sdlog),
#   r ≈ 0.08 yr⁻¹, K ≈ 0.8 t/ha (stored here as scalars for your model core),
#   target fK ≈ 0.5.  (Σ Incentives = 1 - fK handled in your core.)

T = (
    N=200,

    # Health moderates time availability (same pattern as yours)
    health=dist(mean=0, sigma=2.0, distribution=Normal,
        dependency_fun="1/(1+exp(-2-independent))"),

    # gender: 0 = man, 1 = woman
    gender=dist(mean=0.5, distribution=Bernoulli, random=true),

    # Parental economic status ~ LogNormal (keep same style as your working code: min/max only)
    # Interpreted in $/day scale in the analysis, but here we just need a right-skewed latent.
    parental=dist(min=0.1, max=4.0, distribution=LogNormal),

    # TIME: women ≈ 60% less active fishing time (scaled to [0,1])
    time=dist(min=0.0, max=1.0,
        dependency_fun="clamp( health * (1 - 0.60*gender) * independent , 0, 1)"),

    # EFFICIENCY (CPUE proxy, unitless scaler on [min,max]):
    # women ≈ 0.35 of men; scaled up with parental (capital/gear access)
    efficiency=dist(min=0.015, max=0.20, normalize=false,
        dependency_fun="( (1-gender) + 0.35*gender ) * parental * independent"),

    # Alternative Income Opportunities (AIO) — keep LogNormal with min/max (no meanlog/sdlog)
    # Slightly higher pull for women via dependency_fun; small scale 0.02*parental matches earlier logic.
    AIO=dist(min=0.1, max=1.6, distribution=LogNormal,
        dependency_fun="0.02 * parental * (1 + 0.30*gender) * independent"),

    # Ecological scalars for the core (per ha); your engine can read these or you can keep them elsewhere
    r=0.08,       # yr^-1 (within 0.05–0.12)
    K=0.8,        # t/ha  (≈ 800 kg/ha)
    fK=0.50,      # observed fraction of K (B/K)

    # Drivers feeding your Incentive/Impact construction (Σ I = 1 - fK is enforced in core):
    ū=dist(min=-0.1, max=0.1, dependency_fun="time * efficiency"),
    w̃=dist(min=-0.1, max=0.1, dependency_fun="(AIO ./ (efficiency + 1e-6)) .+ independent"),

    # Adjustment rate
    α=dist(min=0.1, max=0.1, distribution=Uniform)
)

sample!(T, random=true)

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

_unit_string(v) = begin
    hasproperty(v, :unit) ? getfield(v, :unit) : nothing
end

function _append_unit(label::AbstractString, value)
    unit = _unit_string(value)
    unit === nothing && return label
    unit_str = unit isa AbstractString ? unit : try
        string(unit)
    catch
        ""
    end
    isempty(unit_str) && return label
    return string(label, " (", unit_str, ")")
end

# ----------------------------------------------------------------------------
"""
pairgrid_blank_upper_redblue_with_dep(
    data, vars;
    labels=nothing, corr=:pearson,
    cellsize=(120,120), markersize=3, alpha=0.6,
    cmap=:coolwarm, reverse_cmap=false,
    dep_range=(1:4, 5:8),
    phase_plot::Union{Nothing,Tuple{Any,Any}}=nothing
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
    dep_range=(1:4, 5:8),
    phase_plot::Union{Nothing,Tuple{Any,Any}}=nothing,
    incentive_color=:darkorange,
    impact_color=:darkorange,
    incentive_label_color=:darkorange,
    impact_label_color=:darkorange,
    time_color=:forestgreen,
    efficiency_color=:forestgreen,
    aio_color=:forestgreen,
    time_label_color=:forestgreen,
    efficiency_label_color=:forestgreen,
    aio_label_color=:forestgreen
)
    @assert corr in (:pearson, :spearman)

    cols = [Float64.(getproperty(data, s)) for s in vars]
    n = length(first(cols))
    @assert all(length(c) == n for c in cols)

    lab = _coerce_labels(vars, labels)
    lab = [_append_unit(lab[i], getproperty(data, vars[i])) for i in 1:length(vars)]
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


    # Left row labels (0th col) with optional coloring for impact/incentive/time/efficiency/AIO
    for i in 1:p
        lcol = vars[i] == :w̃ ? incentive_label_color :
               vars[i] == :ū ? impact_label_color :
               vars[i] == :time ? time_label_color :
               vars[i] == :efficiency ? efficiency_label_color :
               vars[i] == :AIO ? aio_label_color : :black
        fig[i, 0] = Label(fig, lab[i]; halign=:right, valign=:center,
            fontsize=12, font=:bold, rotation=pi / 2, tellheight=false, color=lcol)
    end
    # Bottom column labels (row p+1) with optional coloring for impact/incentive/time/efficiency/AIO
    for j in 1:p
        bcol = vars[j] == :w̃ ? incentive_label_color :
               vars[j] == :ū ? impact_label_color :
               vars[j] == :time ? time_label_color :
               vars[j] == :efficiency ? efficiency_label_color :
               vars[j] == :AIO ? aio_label_color : :black
        fig[p+1, j] = Label(fig, lab[j]; halign=:center, valign=:top,
            fontsize=12, font=:bold, tellwidth=false, color=bcol)
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
                # Custom colors for :w̃ (incentive), :ū (impact), :time, :efficiency, :AIO
                kcol = vars[i] == :w̃ ? incentive_color :
                       vars[i] == :ū ? impact_color :
                       vars[i] == :time ? time_color :
                       vars[i] == :efficiency ? efficiency_color :
                       vars[i] == :AIO ? aio_color : :gray20
                lines!(ax, kd.x, kd.density; color=kcol)
                band!(ax, kd.x, zero.(kd.density), kd.density; color=kcol, transparency=true, alpha=0.5)
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
            hidexdecorations!(ax; label=false, ticks=true, grid=false)
        end
        # show y ticks only on left column, hide elsewhere (preserve grids)
        if j == 1
            # Don't override custom gender ticks
            if !is_gender_violin
                ax.yticks = LinearTicks(3)
            end
        else
            hideydecorations!(ax; label=false, ticks=true, grid=false)
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
    # Dependency graph with colored labels for impact/incentive
    dep_label_colors = Dict{Symbol,Any}()
    dep_label_colors[:w̃] = incentive_label_color
    dep_label_colors[:ū] = impact_label_color
    dep_label_colors[:time] = time_label_color
    dep_label_colors[:efficiency] = efficiency_label_color
    dep_label_colors[:AIO] = aio_label_color
    dependency_graph_plot!(depplot, data; label_colors=dep_label_colors)

    # Optional phase plot region
    if phase_plot !== nothing
        pax = Axis(fig[phase_plot[1], phase_plot[2]];
            #title="Open Access",
            xlabel="Resource level-Incentive threshold",
            ylabel="Participation",
            yaxisposition=:right)
        hidespines!(pax)
        hidedecorations!(pax)
        phase_plot!(pax, sim(scenario(data)))
    end
    colgap!(fig.layout, 8)
    rowgap!(fig.layout, 6)
    return fig
end



function build_pairgrid_figure(; data=T,
    vars=[:gender, :health, :parental, :time, :efficiency, :AIO, :ū, :w̃],
    labels=["Gender", "Health", "Parental", "Time", "Efficiency", "AIO", "Impact", "Incentive"],
    corr=:spearman,
    cellsize=(90, 90), markersize=3,
    cmap=:coolwarm, reverse_cmap=false,
    dep_range=(1:4, 5:8), phase_plot=(5:6, 7:8),
    incentive_color=:darkorange, impact_color=:darkorange,
    incentive_label_color=:darkorange, impact_label_color=:darkorange,
    time_color=:forestgreen, efficiency_color=:forestgreen, aio_color=:forestgreen,
    time_label_color=:forestgreen, efficiency_label_color=:forestgreen, aio_label_color=:forestgreen)
    return pairgrid_blank_upper_redblue_with_dep(
        data, vars; labels, corr,
        cellsize, markersize, cmap, reverse_cmap,
        dep_range, phase_plot,
        incentive_color=incentive_color, impact_color=impact_color,
        incentive_label_color=incentive_label_color, impact_label_color=impact_label_color,
        time_color=time_color, efficiency_color=efficiency_color, aio_color=aio_color,
        time_label_color=time_label_color, efficiency_label_color=efficiency_label_color, aio_label_color=aio_label_color,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    try
        sample!(T, random=true)
    catch
    end
    fig = build_pairgrid_figure()
    save("pairgrid_blank_upper_redblue_with_dep.png", fig)
    display(fig)
end
