if !isdefined(Main, :SED)
    error("Load SED first: include(\"SED.jl\"); using .SED")
end
using .SED
using CairoMakie
using ColorSchemes
using Statistics: mean
using Printf: @sprintf

"""
    regscan_simple(; s=SED.high_impact(), warmstart::Symbol=:chain)

Simplified regulation scan figure:
- Same curated policies as regscan_plot.jl
- Outcomes shown: RR, ToR, GI, EH, Gov (no RI row)
- No heatmap row; one clean line plot per (policy × outcome)
"""
function regscan_simple(; s=SED.high_impact(), warmstart::Symbol=:chain, Tcontext=nothing,
    weights = (kR=0.5, kT=1.0, kG=-0.2, kE=0.0, kI=0.0),
    tourism_factor::Float64=0.2)
    # If no Tcontext was provided, try to pick up a top-level `T` with gender
    if Tcontext === nothing
        try
            if isdefined(Main, :T) && hasproperty(Main.T, :gender)
                Tcontext = Main.T
            end
        catch
        end
    end
    getdata(v) = hasproperty(v, :data) ? v.data : v
    sel_top = (w̃, n) -> sortperm(getdata(w̃), rev=true)[1:n]
    sel_bot = (w̃, n) -> sortperm(getdata(w̃))[1:n]
    # Selection by opportunities instead of incentives
    sel_top_opp = (opportunities, n) -> sortperm(getdata(opportunities), rev=true)[1:n]
    sel_bot_opp = (opportunities, n) -> sortperm(getdata(opportunities))[1:n]

    policies = [
        # Exclusive Use Rights — select by opportunities (high vs low)
        SED.with_policy(s; SED.exclusive_use_rights_by_opportunities_kit(; selector=sel_top_opp)...),  # HIGH opp excluded
        SED.with_policy(s; SED.exclusive_use_rights_by_opportunities_kit(; selector=sel_bot_opp)...),  # LOW opp excluded
        SED.with_policy(s; SED.tradable_use_rights_kit(; target=:effort, market_rate=0.05)...),  # TUR — effort
        SED.with_policy(s; SED.tradable_use_rights_kit(; target=:yield,  market_rate=0.05)...),  # TUR — yield
        SED.with_policy(s; SED.protected_area_kit(; m=0.3)...),                                   # PA m=0.3
        # PA m=0.3 + additional alternative incomes proportional to regulation (tourism)
        begin
            base_pa = SED.with_policy(s; SED.protected_area_kit(; m=0.3)...)
            SED.with_policy(base_pa; income_extra_fun=(x,p,t)->fill(tourism_factor * p.regulation, p.N))
        end,
    ]

    policylabels = [
        "Use Rights\nHIGH opp\nexcluded",
        "Use Rights\nLOW opp\nexcluded",
        "Tradable \nUse Rights\nEFFORT",
        "Tradable \nUse Rights\nYIELD",
        "Protected Area\n\nmobility=0.3",
        "Protected Area\n\nmobility=0.3\n(+ tourism)",
    ]

    # Run warm-started scans with configurable governance weights (single row)
    (; kR, kT, kG, kE, kI) = weights
    RS = [SED.regulation_scan(p; kR, kT, kG, kE, kI, warmstart=warmstart) for p in policies]
    # Governance-optimal regulation per policy (used for overlay and phase plots)
    regs_go = [rs.r[rs.oGov] for rs in RS]

    # Optional gender baseline from Open Access at regulation=0.0
    getdata(v) = hasproperty(v, :data) ? v.data : v
    gvec = (Tcontext !== nothing && hasproperty(Tcontext, :gender)) ? getdata(getfield(Tcontext, :gender)) : nothing
    oa_sol = SED.sim(s; regulation=0.0)
    oa_inc = SED.incomes(oa_sol)
    female_baseline_pct = nothing
    # Only use gender context if it exists and matches scenario length
    if gvec !== nothing && length(gvec) == s.N
        fem_idx = findall(gvec .== 1)
        if !isempty(fem_idx) && !iszero(sum(oa_inc.total))
            female_baseline_pct = 100 * mean(oa_inc.total[fem_idx]) / mean(oa_inc.total)
        end
    end

    outcomes = [:RR, :ToR, :GI, :Gov]
    # Build dynamic governance weighting label using Unicode superscripts
    function weight_label(weights)
        sup = Dict('0'=>'⁰','1'=>'¹','2'=>'²','3'=>'³','4'=>'⁴','5'=>'⁵','6'=>'⁶','7'=>'⁷','8'=>'⁸','9'=>'⁹','-'=>'⁻','.'=>'⋅')
        to_sup(s::AbstractString) = join((get(sup, c, string(c)) for c in s))
        superscript(k::Real) = to_sup(@sprintf("%.2f", k))
        parts = String[]
        wmap = [("R", weights.kR), ("T", weights.kT), ("G", weights.kG), ("E", weights.kE), ("I", weights.kI)]
        for (name, k) in wmap
            if k != 0
                push!(parts, string(name, superscript(k)))
            end
        end
        return isempty(parts) ? "Governance\nweighted" : "Governance\nweighted\n" * join(parts, " · ")
    end
    labels = Dict(
        :RR => "Resource\nRevenues",
        :ToR => "Total\nRevenues",
        :GI => "Gini\n(↓ better)",
        :Gov => weight_label(weights),
    )

    f = Figure(size=(1050, 935))

    # First column: outcome titles
    for (j, o) in enumerate(outcomes)
        Label(f[j, 0], text=labels[o], tellheight=false)
    end

    # Panels: rows = outcomes, cols = policies
    axes = Matrix{Axis}(undef, length(outcomes), length(RS))
    valabbr = Dict(:RR=>"R", :ToR=>"T", :GI=>"G", :Gov=>"C")
    for (i, rs) in enumerate(RS)
        pol_color = ColorSchemes.tab20[i]
        for (j, o) in enumerate(outcomes)
            ax = Axis(f[j, i])
            ax.xgridvisible[] = true
            ax.ygridvisible[] = true
            axes[j, i] = ax
            yvals = getfield(rs, o)
            lines!(ax, rs.r, yvals, color=pol_color, linewidth=3)

            # mark the per-outcome optimum (policy-colored)
            osym = Symbol("o" * String(o))
            ridx = getfield(rs, osym)
            rx = rs.r[ridx]
            ry = yvals[ridx]
            scatter!(ax, [rx], [ry]; color=pol_color)
            vlines!(ax, [rx]; color=pol_color, linestyle=:dash, linewidth=1)
            # overlay governance-optimal regulation (common reference)
            vlines!(ax, [regs_go[i]]; color=:crimson, linewidth=2)
            # Optional: compute Δ female share at this policy and regulation
            fem_delta_str = ""
            if !isempty(fem_idx) && female_baseline_pct !== nothing
                sol_pol = SED.sim(policies[i]; regulation=rx)
                inc_pol = SED.incomes(sol_pol)
                fem_pct = 100 * mean(inc_pol.total[fem_idx]) / mean(inc_pol.total)
                delta = fem_pct - female_baseline_pct
                fem_delta_str = string("  ♀=", round(delta, digits=0), "%")
            end
            valstr = valabbr[o]
            valdigits = (o == :GI) ? 2 : 3
            ax.title[] = string("r=", round(rx, digits=2), "  ", valstr, "=", round(ry, digits=valdigits), fem_delta_str)
            ax.titlegap[] = 4
            ax.titlealign[] = :left
            ax.titlecolor[] = pol_color
            ax.titlesize[] = 10
            hidespines!(ax)
            if j < length(outcomes)
                hidexdecorations!(ax; grid=false)
            end
            if i > 1
                hideydecorations!(ax; grid=false)
            end
        end
        Label(f[0, i], text=policylabels[i], color=pol_color, tellwidth=false)
    end

    # Link axes across panels for comparability
    for j in 1:length(outcomes)
        linkxaxes!(axes[j, :]...)
        linkyaxes!(axes[j, :]...)
    end

    # Set informative xlabels on the bottom row
    policyxlabels = [
        "fraction excluded",
        "fraction excluded",
        "1 - effort quota",
        "1 - yield quota",
        "fraction protected",
        "fraction protected",
    ]
    for i in 1:length(RS)
        axes[end, i].xlabel = policyxlabels[i]
    end

    # Phase plots at governance-optimal regulation per policy (bottom row)
    phase_row = length(outcomes) + 1
    for (i, ppol) in enumerate(policies)
        pax = Axis(f[phase_row, i])
        hidespines!(pax)
        hidedecorations!(pax)
        sol = SED.sim(ppol; regulation=regs_go[i])
        SED.phase_plot!(pax, sol)
    end
    # Left label for phase row (narrow width)
    Label(f[phase_row, 0], text="Phase\n(best Gov)", tellheight=false)

    return f
end

if abspath(PROGRAM_FILE) == @__FILE__
    f = regscan_simple()
    save(joinpath(@__DIR__, "figures", "regscan_simple.png"), f)
end
