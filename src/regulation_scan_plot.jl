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
function default_regulation_scan_policies(s; tourism_factor::Float64=0.002)
    policies = [
        scenario(s, policy="Exclusive Use Rights", selector=:top),
        scenario(s, policy="Exclusive Use Rights", selector=:bottom),
        scenario(s, policy="Tradable Use Rights", policy_target=:effort, market_rate=0.05, buyer_bias=0.0),
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
        "Exclusive Use Rights (top)",
        "Exclusive Use Rights (bottom)",
        "Tradable Use Rights (effort)",
        #"Tradable Use Rights (effort, rich)",
        #"Tradable Use Rights (effort, poor)",
        "Tradable Use Rights (yield)",
        "Protected Area",
        "Protected Area + Tourism"
    ]

    policyxlabels = [
        "Fraction of excluded users",
        "Fraction of excluded users",
        "Total Effort Reduction",
        #"Total Effort Reduction",
        #"Total Effort Reduction",
        "Total Yield Reduction",
        "Fraction of protected area",
        "Fraction of protected area"
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

    nrows = length(outcomes) + 1 + (heatmap ? 1 : 0) + (resource ? 1 : 0)
    row_h = 180 # Approx height per row
    height = Int(round(nrows * row_h * sc))

    f = Figure(size=(width, height))

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

    if resource
        # Add Resource Row
        res_row = phase_row
        phase_row += 1

        for (i, rs) in enumerate(RS)
            rax = Axis(f[res_row, i])
            # Plot resource level
            lines!(rax, rs.r, rs.resources, color=:green, linewidth=2)

            # Add marker for optimal governance point
            ridx = getfield(rs, :oGov)
            scatter!(rax, [rs.r[ridx]], [rs.resources[ridx]]; color=:green)
            vlines!(rax, [regs_go[i]]; color=:crimson, linewidth=2)

            hidespines!(rax)
            if i > 1
                hideydecorations!(rax; grid=false)
            else
                rax.ylabel = "Resource"
            end
            hidexdecorations!(rax; grid=false)
        end
        Label(f[res_row, 0], text="Resource\nStock", tellheight=false, font=:bold, halign=:right)
    end

    if heatmap
        # Add Heatmap Row
        heatmap_row = phase_row
        phase_row += 1

        # Determine global min/max for color scale across all policies
        # to make them comparable (for effort/sols)
        vmin = Inf
        vmax = -Inf
        for rs in RS
            vmin = min(vmin, minimum(rs.sols))
            vmax = max(vmax, maximum(rs.sols))
        end

        for (i, rs) in enumerate(RS)
            hax = Axis(f[heatmap_row, i])
            # sols is (m, N). We want Regulation (m) on x, Actors (N) on y.
            # Makie expects z to be (nx, ny) where nx=length(x) and ny=length(y).
            # Here x=r (length m), y=1:N (length N).
            # So z must be (m, N).
            # This matches sols dimensions directly. No transpose needed.

            # Custom colormap matching policy color
            pol_color = cs[mod1(i, length(cs))]
            cmap = cgrad(["#f1f1f1", pol_color])

            hm = heatmap!(hax, rs.r, 1:s.N, rs.sols; colorrange=(vmin, vmax), colormap=cmap)

            hidespines!(hax)
            if i > 1
                hideydecorations!(hax; grid=false)
            else
                hax.ylabel = "Actors"
            end
            hidexdecorations!(hax; grid=false)
        end
        Label(f[heatmap_row, 0], text="Effort\nDist.", tellheight=false, font=:bold, halign=:right)
    end

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
