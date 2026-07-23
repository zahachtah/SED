using Statistics: mean
using CairoMakie
using ColorSchemes
using Printf: @sprintf

getdata_or_values(v) = hasproperty(v, :data) ? v.data : v

insights_row = [
    "Regulation increases stocks by curbing overuse. However, Yield-based TURs are risky: their optimal point sits on a 'cliff edge,' where slight over-allocation leads to a sharp collapse.",
    "Rights-based policies successfully target Maximum Sustainable Yield (MSY). In contrast, Protected Areas (PA) reduce revenue here because spillover benefits fail to compensate for the loss of fishing grounds.",
    "TURs theoretically maximize total community income (fishing + alternative) and distribution (gini). Protected Areas only compete if they attract significant external revenue, like tourism, to offset lost fishing income by increase AIO.",
    "For this case, TURs reduce inequality and boost female income by ~20%. However, basing rights on 'historical use' erases these gains. Conversely, tourism revenues linked to PAs often flow to the wealthy, worsening inequality.",
    "By weighting specific goals—resource revenue (fishers), total income (society), equality (marginalized groups) or environmental concerns (resource stock)—we can simulate how power dynamics shape policy outcomes.",
    "",
    "",
    ""
]

"""
    default_regulation_scan_policies(s; tourism_factor=0.2)

Return the curated set of policy scenarios and metadata used by `regulation_scan_plot`.
Edit this helper to change the default lineup; pass a custom `policies` argument
to `regulation_scan_plot` to override programmatically.
"""
function default_regulation_scan_policies(s; tourism_factor::Float64=0.002)
    policies = [
        scenario(s, policy="Exclusive Use Rights", selector=:top),
        scenario(s, policy="Exclusive Use Rights", selector=:bottom),
        scenario(s, policy="Tradable Use Rights", policy_target=:effort, market_rate=0.05, buyer_bias=0.0),
        scenario(s, policy="Tradable Use Rights", policy_target=:effort, market_rate=0.05, buyer_bias=0.0, historical_use_rights=true),
        #scenario(s, policy="Tradable Use Rights", policy_target=:effort, market_rate=0.05, buyer_bias=+0.9),
        #scenario(s, policy="Tradable Use Rights", policy_target=:effort, market_rate=0.05, buyer_bias=-0.9),
        scenario(s, policy="Tradable Use Rights", policy_target=:yield, market_rate=0.05, buyer_bias=0.0),
        scenario(s, policy="Protected Area", m=0.3),
        # For the custom tourism case, we need a way to inject the income function.
        # Since we removed `with_policy`, we can just attach it to the scenario.
        let
            base_pa = scenario(s, policy="Protected Area", m=0.3)
            change(base_pa, income_extra_fun=(x, p, t) -> fill(tourism_factor * p.regulation, p.N))
        end
    ]

    policylabels = [
        "for low AIO",
        "for high AIO",
        "effort, shared",
        "effort, historical",
        "yield, shared",
        "spillover",
        "spillover + Tourism"
    ]

    policyxlabels = [
        "Excluded",
        "Excluded",
        "Reduction",
        "Reduction",
        "Reduction",
        "Protected",
        "Protected"
    ]

    return policies, policylabels, policyxlabels
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
    tourism_factor=0.005,
    policies=nothing,
    policylabels=nothing,
    policyxlabels=nothing,
    heatmap::Bool=false,
    resource::Bool=false)

    if policies === nothing
        policies, policylabels, policyxlabels = default_regulation_scan_policies(s; tourism_factor)
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

    # Calculate global max for Gov to normalize to %
    max_Gov = maximum(maximum(rs.Gov) for rs in RS)
    if max_Gov <= 1e-9
        max_Gov = 1.0
    end

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
        Dict(
            :RR => rich(rich("R", font=:bold, size=16), "esource Revenues"),
            :ToR => rich(rich("T", font=:bold, size=16), "otal Revenues"),
            :GI => rich(rich("G", font=:bold, size=16), "ini (← better)"),
            :Gov => rich("Weighted Goals", font=:bold, size=16),
        )
    end

    sc = 0.7
    ncols = length(policies)
    # Add extra width for the text column
    base_w = 1050.0
    width = Int(round((base_w * (ncols / 6) + 200) * sc))

    # Calculate rows
    # Resource is now always first if enabled
    # Then outcomes
    # Then Heatmap (if enabled)
    # Then Phase (always last)
    # Then Insights Row (Bottom)

    # Row 0: Grouped Labels
    # Row 1: Individual Labels
    # Row 2+: Data
    current_row = 2

    nrows = length(outcomes) + 1 + (heatmap ? 1 : 0) + (resource ? 1 : 0) + 1 # +1 for Insights
    # Add 1 more row for the extra labels row (we have 0 and 1 now, previously just 0)
    # Actually Makie layout indices can be anything. But we calculated `nrows` for height.
    # We added 1 row of labels (Individual). Grouped is at 0.
    # So we need to increase `nrows` by 1 to account for the extra label row?
    # Or just increase height?
    # Let's increase nrows by 1.
    nrows += 1

    row_h = 180 # Approx height per row
    height = Int(round(nrows * row_h * sc))

    f = Figure(size=(width, height), backgroundcolor=:white)



    cs = ColorSchemes.tab20

    # --- Resource Row (Top) ---
    if resource
        for (i, rs) in enumerate(RS)
            # Custom color mapping: 3 and 4 share the same color
            c_idx = i > 3 ? i - 1 : i
            pol_color = cs[mod1(c_idx, length(cs))]
            rax = Axis(f[current_row, i], backgroundcolor=:gray95)
            # Plot resource level
            lines!(rax, rs.r, rs.resources, color=pol_color, linewidth=2)

            # Add marker for optimal governance point
            ridx = getfield(rs, :oGov)
            scatter!(rax, [rs.r[ridx]], [rs.resources[ridx]]; color=pol_color)
            vlines!(rax, [regs_go[i]]; color=:crimson, linewidth=2)

            hidespines!(rax)
            if i > 1
                hideydecorations!(rax; grid=false)
            else
                rax.ylabel = "Resource Density"
                rax.ylabelsize = 12
                rax.ylabelcolor = :black
                rax.ylabelrotation = π / 2
            end
            hidexdecorations!(rax; grid=false)
            rax.xgridvisible = false
            rax.ygridvisible = false
        end

        # Add text box for Resource row
        Label(f[current_row, ncols+1], text=insights_row[1],#"Resource stocks increase with regulation when use goes under open access levels. Note that this level is in the limit of the optima for TUR yield creating the highly steep response",
            tellheight=false, width=180, justification=:left, halign=:left, word_wrap=true, fontsize=12)#

        current_row += 1
    end

    # --- Main Outcomes Rows ---
    axes = Matrix{Axis}(undef, length(outcomes), length(RS))
    valabbr = Dict(:RR => "R", :ToR => "T", :GI => "G", :Gov => "W")

    for (j, o) in enumerate(outcomes)
        for (i, rs) in enumerate(RS)
            # Custom color mapping: 3 and 4 share the same color
            c_idx = i > 3 ? i - 1 : i
            pol_color = cs[mod1(c_idx, length(cs))]
            ax = Axis(f[current_row, i], backgroundcolor=:gray95)
            ax.xgridvisible = false
            ax.ygridvisible = false

            if o == :Gov
                ax.xticks = ([0, 1], ["0", "1"])
            end

            axes[j, i] = ax
            yvals = getfield(rs, o)

            # Normalize Gov to % of max
            if o == :Gov
                yvals = (yvals ./ max_Gov) .* 100
            end

            lines!(ax, rs.r, yvals, color=pol_color, linewidth=3)
            osym = Symbol("o" * String(o))
            ridx = getfield(rs, osym)
            rx = rs.r[ridx]
            ry = yvals[ridx]
            scatter!(ax, [rx], [ry]; color=pol_color)
            vlines!(ax, [rx]; color=pol_color, linestyle=:dash, linewidth=1)
            vlines!(ax, [regs_go[i]]; color=:crimson, linewidth=2)

            fem_delta_str = ""
            delta_val = 0
            if !isempty(fem_idx) && female_baseline_pct !== nothing
                sol_pol = sim(policies[i]; regulation=rx)
                inc_pol = incomes(sol_pol)
                fem_pct = 100 * mean(inc_pol.total[fem_idx]) / mean(inc_pol.total)
                delta_val = round(Int, fem_pct - female_baseline_pct)
                fem_delta_str = string(": ", delta_val, "%")
            end
            valstr = valabbr[o]

            val_display = if o == :Gov
                string(round(Int, ry))
            else
                string(round(ry, digits=(o == :GI ? 2 : 3)))
            end

            base_title = string(val_display, (o == :Gov ? "%" : ""), "@", round(rx, digits=2))#valstr, ":",

            if !isempty(fem_delta_str)
                # Use rich text for female symbol: bold and larger
                ax.title[] = rich(base_title, "  ", rich("♀", font=:bold, fontsize=14), fem_delta_str)
            else
                ax.title[] = base_title
            end
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
            else
                # Set Y-Label for first column
                ax.ylabel = labels[o]
                ax.ylabelsize = 12
                ax.ylabelcolor = :black
                ax.ylabelrotation = π / 2
            end
        end

        # Add text box for this outcome row
        Label(f[current_row, ncols+1], text=insights_row[j+1],#"Description for $(labels[o]) placeholder. This text wraps and explains the row.",
            tellheight=false, width=180, justification=:left, halign=:left, word_wrap=true, fontsize=12)

        current_row += 1
    end

    for j in 1:length(outcomes)
        linkxaxes!(axes[j, :]...)
        linkyaxes!(axes[j, :]...)
    end

    # Policy Labels (Top)
    # Grouped Labels
    Label(f[0, 1:2], text="Exclusive Use Rights (EUR)", font=:bold, fontsize=16, tellwidth=false)
    Label(f[0, 3:5], text="Tradable Use Rights (TUR)", font=:bold, fontsize=16, tellwidth=false)
    Label(f[0, 6:7], text="Protected Area (PA)", font=:bold, fontsize=16, tellwidth=false)

    # Individual Labels (Row 1, below grouped labels)
    for i in 1:length(RS)
        # Custom color mapping: 3 and 4 share the same color
        c_idx = i > 3 ? i - 1 : i
        Label(f[1, i], text=policylabels[i], color=cs[mod1(c_idx, length(cs))], tellwidth=false, font=:bold, fontsize=12)
    end

    # Adjust current_row to start after labels
    # Row 0 is Grouped Labels
    # Row 1 is Individual Labels
    # So data starts at Row 2
    # current_row = 2 # Already initialized at top

    if heatmap
        # Add Heatmap Row
        # Determine global min/max for color scale across all policies
        vmin = Inf
        vmax = -Inf
        for rs in RS
            vmin = min(vmin, minimum(rs.sols))
            vmax = max(vmax, maximum(rs.sols))
        end

        for (i, rs) in enumerate(RS)
            hax = Axis(f[current_row, i], backgroundcolor=:gray95)
            hax.xgridvisible = false
            hax.ygridvisible = false

            # Custom colormap matching policy color
            # Custom color mapping: 3 and 4 share the same color
            c_idx = i > 3 ? i - 1 : i
            pol_color = cs[mod1(c_idx, length(cs))]
            cmap = cgrad(["#f1f1f1", pol_color])

            hm = heatmap!(hax, rs.r, 1:s.N, rs.sols; colorrange=(vmin, vmax), colormap=cmap)

            hidespines!(hax)
            if i > 1
                hideydecorations!(hax; grid=false)
            else
                hax.ylabel = "Effort\nDist."
                hax.ylabelsize = 12
                hax.ylabelrotation = π / 2
            end
            hidexdecorations!(hax; grid=false)
        end

        # Add text box for Heatmap row
        Label(f[current_row, ncols+1], text="Heatmap description placeholder. Shows effort distribution across agents.",
            tellheight=false, width=180, justification=:left, halign=:left, word_wrap=true, fontsize=11)

        current_row += 1
    end

    # --- Phase Plot Row ---
    for (i, ppol) in enumerate(policies)
        pax = Axis(f[current_row, i], backgroundcolor=:gray95)
        pax.xgridvisible = false
        pax.ygridvisible = false
        hidespines!(pax)
        hidedecorations!(pax)
        sol = sim(ppol; regulation=regs_go[i])
        phase_plot!(pax, sol)
        if i == 5
            pax.xlabel = "Resource level"
        end
        if i == 1
            pax.ylabel = "Participation (fraction)"
            pax.ylabelsize = 12
            pax.ylabelrotation = π / 2
            pax.ylabelvisible = true
        end
    end

    # Add text box for Phase row
    Label(f[current_row, ncols+1], text="Incentives and Impact curves for the different policies provide a fingerprint of hwo the distributional effects of each policy play out. \n⚪ =Open access, \n⚫ =Policy outcome",
        tellheight=false, width=180, justification=:left, halign=:left, word_wrap=true, fontsize=11)

    current_row += 1

    # --- Insights Row (Bottom) ---
    # Textboxes spanning columns: 1:2, 3:5, 6:7
    # Background color: :lemonchiffon (light yellow)

    insight_bg = :lemonchiffon

    Label(f[current_row, 1:2], text="Exclusive Use Rights are robust if allocated to users with low alternative income (AIO). In practice, however, high-SES users often capture these rights. This exclusion lowers participation and drives up inequality by concentrating benefits.",
        tellheight=true, tellwidth=false, halign=:left, valign=:top,
        padding=(10, 10, 10, 10), word_wrap=true)


    Label(f[current_row, 3:5], text="Yield-based TURs lack resilience: their optimal point sits on a 'cliff edge' where slight over-allocation causes instability. Effort-based TURs are robust against this. Critically, basing rights on 'historical use' acts as a giveaway to the wealthy, failing to improve general incomes while worsening inequality.",
        tellheight=true, tellwidth=false, halign=:left, valign=:top,
        padding=(10, 10, 10, 10), word_wrap=true)


    Label(f[current_row, 6:7], text="Protected Areas (PA) rarely boost incomes alone, as spillover fails to offset lost fishing grounds. While tourism can make total social income positive, it often worsens inequality because high-AIO users are better positioned to capture the new tourism revenue.",
        tellheight=true, tellwidth=false, halign=:left, valign=:top,
        padding=(10, 10, 10, 10), word_wrap=true)


    # Insights Label (Bottom Right Corner)
    #Box(f[current_row, ncols+1], color=insight_bg)
    Label(f[current_row, ncols+1], text="←  Insights ↑",
        tellheight=false, width=180, halign=:center, valign=:center, font=:bold, fontsize=20)

    # X-Labels (Bottom of Outcomes or Heatmap)
    # We add x-labels to the last row of the main stack (before Phase)
    for i in 1:length(RS)
        axes[end, i].xlabel = policyxlabels[i]
        if !heatmap
            axes[end, i].xticklabelsvisible = true
            axes[end, i].xlabelvisible = true
        end
    end

    # Reduce gaps
    colgap!(f.layout, 10)
    rowgap!(f.layout, 10)
    return f
end
