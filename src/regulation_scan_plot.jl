using Statistics: mean
using CairoMakie
using ColorSchemes
using Printf: @sprintf

getdata_or_values(v) = hasproperty(v, :data) ? v.data : v

"""
    default_regulation_scan_policies(s; tourism_factor=0.2)

Return the curated set of policy scenarios and metadata used by `regulation_scan_plot`.
Edit this helper to change the default lineup; pass a custom `policies` argument
to `regulation_scan_plot` to override programmatically.
"""
function default_regulation_scan_policies(s; tourism_factor::Float64=0.2)
    sel_top = (arr, n) -> sortperm(getdata_or_values(arr), rev=true)[1:n]
    sel_bot = (arr, n) -> sortperm(getdata_or_values(arr))[1:n]

    policies = [
        with_policy(s; exclusive_use_rights_by_opportunities_kit(; selector=sel_top)...),
        with_policy(s; exclusive_use_rights_by_opportunities_kit(; selector=sel_bot)...),
        with_policy(s; tradable_use_rights_kit(; target=:effort, market_rate=0.05, buyer_bias=0.0)...),
        with_policy(s; tradable_use_rights_kit(; target=:effort, market_rate=0.05, buyer_bias=+0.9)...),
        with_policy(s; tradable_use_rights_kit(; target=:effort, market_rate=0.05, buyer_bias=-0.9)...),
        with_policy(s; tradable_use_rights_kit(; target=:yield, market_rate=0.05, buyer_bias=0.0)...),
        with_policy(s; protected_area_kit(; m=0.3)...),
        begin
            base_pa = with_policy(s; protected_area_kit(; m=0.3)...)
            with_policy(base_pa; income_extra_fun=(x, p, t) -> fill(tourism_factor * p.regulation, p.N))
        end,
    ]

    policylabels = [
        "Use Rights\nHIGH opp\nexcluded",
        "Use Rights\nLOW opp\nexcluded",
        "Tradable \nUse Rights\nEFFORT",
        "TUR Effort\n(regressive)",
        "TUR Effort\n(progressive)",
        "Tradable \nUse Rights\nYIELD",
        "Protected Area\n\nmobility=0.3",
        "Protected Area\n\nmobility=0.3\n(+ tourism)",
    ]

    policyxlabels = [
        "fraction excluded",
        "fraction excluded",
        "1 - effort quota",
        "1 - effort quota",
        "1 - effort quota",
        "1 - yield quota",
        "fraction protected",
        "fraction protected",
    ]

    return (; policies, policylabels, policyxlabels)
end

"""
    regulation_scan_plot(; s=high_impact(), warmstart=:chain, Tcontext=nothing,
                           weights=(kR=0.5, kT=1.0, kG=-0.2, kE=0.0, kI=0.0),
                           tourism_factor=0.2,
                           policies=nothing,
                           policylabels=nothing,
                           policyxlabels=nothing)

Generate the simplified regulation scan figure. Provide `policies`, `policylabels`,
and `policyxlabels` to customize the lineup, or omit them to use
`default_regulation_scan_policies`.
"""
function regulation_scan_plot(; s=high_impact(), warmstart::Symbol=:chain, Tcontext=nothing,
    weights=(kR=0.5, kT=1.0, kG=-0.2, kE=0.0, kI=0.0),
    tourism_factor::Float64=0.2,
    policies=nothing,
    policylabels=nothing,
    policyxlabels=nothing)

    if policies === nothing
        defaults = default_regulation_scan_policies(s; tourism_factor=tourism_factor)
        policies = defaults.policies
        policylabels === nothing && (policylabels = defaults.policylabels)
        policyxlabels === nothing && (policyxlabels = defaults.policyxlabels)
    end

    policylabels === nothing && (policylabels = ["Policy $(i)" for i in eachindex(policies)])
    policyxlabels === nothing && (policyxlabels = fill("regulation", length(policies)))

    length(policylabels) == length(policies) || error("policylabels length must match number of policies")
    length(policyxlabels) == length(policies) || error("policyxlabels length must match number of policies")

    if Tcontext === nothing
        try
            if isdefined(Main, :T) && hasproperty(Main.T, :gender)
                Tcontext = Main.T
            end
        catch
        end
    end

    (; kR, kT, kG, kE, kI) = weights
    RS = [regulation_scan(p; kR, kT, kG, kE, kI, warmstart=warmstart) for p in policies]
    regs_go = [rs.r[rs.oGov] for rs in RS]

    gvec = (Tcontext !== nothing && hasproperty(Tcontext, :gender)) ? getdata_or_values(getfield(Tcontext, :gender)) : nothing
    oa_sol = sim(s; regulation=0.0)
    oa_inc = incomes(oa_sol)
    female_baseline_pct = nothing
    fem_idx = Int[]
    if gvec !== nothing && length(gvec) == s.N
        fem_idx = findall(gvec .== 1)
        if !isempty(fem_idx) && !iszero(sum(oa_inc.total))
            female_baseline_pct = 100 * mean(oa_inc.total[fem_idx]) / mean(oa_inc.total)
        end
    end

    outcomes = [:RR, :ToR, :GI, :Gov]
    labels = let
        pairs = [
            ("Resource", weights.kR),
            ("Total", weights.kT),
            ("Gini", weights.kG),
            ("Ecology", weights.kE),
            ("Impact", weights.kI),
        ]
        nz = [(n, v) for (n, v) in pairs if v != 0]
        maxlen = isempty(nz) ? 0 : maximum(length(n) for (n, _) in nz)
        lines = [@sprintf("%s %6.2f", lpad(n * ":", maxlen + 1), v) for (n, v) in nz]
        weight_caption = isempty(lines) ? "Weighted:" : ("Weighted:\n" * join(lines, "\n"))
        Dict(
            :RR => "Resource\nRevenues",
            :ToR => "Total\nRevenues",
            :GI => "Gini\n(↓ better)",
            :Gov => weight_caption,
        )
    end

    sc = 0.9
    ncols = length(policies)
    base_w = 1050.0
    width = Int(round(base_w * (ncols / 6) * sc))
    f = Figure(size=(width, Int(round(935 * sc))))

    for (j, o) in enumerate(outcomes)
        Label(f[j, 0], text=labels[o], tellheight=false, font=:bold, halign=:right)
    end

    axes = Matrix{Axis}(undef, length(outcomes), length(RS))
    valabbr = Dict(:RR => "R", :ToR => "T", :GI => "G", :Gov => "C")
    cs = ColorSchemes.tab20
    for (i, rs) in enumerate(RS)
        pol_color = cs[mod1(i, length(cs))]
        for (j, o) in enumerate(outcomes)
            ax = Axis(f[j, i])
            ax.xgridvisible[] = true
            ax.ygridvisible[] = true
            axes[j, i] = ax
            yvals = getfield(rs, o)
            lines!(ax, rs.r, yvals, color=pol_color, linewidth=3)
            osym = Symbol("o" * String(o))
            ridx = getfield(rs, osym)
            rx = rs.r[ridx]
            ry = yvals[ridx]
            scatter!(ax, [rx], [ry]; color=pol_color)
            vlines!(ax, [rx]; color=pol_color, linestyle=:dash, linewidth=1)
            vlines!(ax, [regs_go[i]]; color=:crimson, linewidth=2)
            fem_delta_str = ""
            if !isempty(fem_idx) && female_baseline_pct !== nothing
                sol_pol = sim(policies[i]; regulation=rx)
                inc_pol = incomes(sol_pol)
                fem_pct = 100 * mean(inc_pol.total[fem_idx]) / mean(inc_pol.total)
                delta = fem_pct - female_baseline_pct
                fem_delta_str = string("  ♀Δ:", round(Int, delta), "%")
            end
            valstr = valabbr[o]
            valdigits = (o == :GI) ? 2 : 3
            fem_str = replace(fem_delta_str, "=" => ":")
            ax.title[] = string("r:", round(rx, digits=2), "  ", valstr, ":", round(ry, digits=valdigits), fem_str)
            ax.titlegap[] = 4
            ax.titlealign[] = :left
            ax.titlecolor[] = pol_color
            ax.titlesize[] = 11
            hidespines!(ax)
            if j < length(outcomes)
                hidexdecorations!(ax; grid=false)
            end
            if i > 1
                hideydecorations!(ax; grid=false)
            end
        end
        Label(f[0, i], text=policylabels[i], color=pol_color, tellwidth=false, font=:bold)
    end

    for j in 1:length(outcomes)
        linkxaxes!(axes[j, :]...)
        linkyaxes!(axes[j, :]...)
    end

    for i in 1:length(RS)
        axes[end, i].xlabel = policyxlabels[i]
    end

    phase_row = length(outcomes) + 1
    for (i, ppol) in enumerate(policies)
        pax = Axis(f[phase_row, i])
        hidespines!(pax)
        hidedecorations!(pax)
        sol = sim(ppol; regulation=regs_go[i])
        phase_plot!(pax, sol)
    end
    Label(f[phase_row, 0], text="Phase\n(best Gov)", tellheight=false, font=:bold)
    return f
end
