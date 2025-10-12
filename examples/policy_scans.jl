if !isdefined(Main, :SED)
    error("Load SED first: include(\"SED.jl\"); using .SED")
end
using .SED
using CairoMakie
using Statistics

"""
    policy_scans(; N=100, m=40)

Builds a baseline from the T-like context and runs regulation_scan across major
policies (Open Access baseline, Exclusive Use Rights, Tradable Use Rights –
effort and yield, Protected Area, Economic Incentives, Development).

Prints optimal regulation for several outcomes: RR, WR, TR, ToR, GI (min), EH, RI, Gov.
"""
function policy_scans(; N=100, m=40)
    # --- Construct T-like context and baseline ---
    T = (
        N=N,
        health=dist(mean=0, sigma=2.0, distribution=Normal, dependency_fun="1/(1+exp(-2-independent))"),
        gender=dist(mean=0.5, distribution=Bernoulli, random=true),
        parental=dist(min=0.1, max=1.0, distribution=LogNormal),
        time=dist(dependency_fun="health*(1-gender*0.5)*independent", min=0, max=1),
        efficiency=dist(min=0.015, max=0.2, dependency_fun="1*parental*(1-gender*0.2)*independent", normalize=false),
        opportunities=dist(min=0.1, max=1.6, distribution=LogNormal, dependency_fun="0.02*parental*(1-gender*0.5)*independent"),
        K=2.0,
        ū=dist(min=-0.1, max=0.1, dependency_fun="time*efficiency"),
        w̃=dist(min=-0.1, max=0.1, dependency_fun="(opportunities ./ efficiency) .+ independent"),
        α=dist(min=0.1, max=0.1, distribution=Uniform)
    )
    sample!(T, random=true)
    base0 = scenario(base(N=T.N); w̃=dist(data=T.w̃), ū=dist(data=T.ū))

    # --- Define policies ---
    pols = [
        (name="Open Access", p=base0),
        (name="Exclusive Rights (lo)", p=scenario(base0; policy="Exclusive Use Rights",
            γ=γ_exclusive_use_rights, regulate=regulate_exclusive_use_rights, reverse=false)),
        (name="Exclusive Rights (hi)", p=scenario(base0; policy="Exclusive Use Rights",
            γ=γ_exclusive_use_rights, regulate=regulate_exclusive_use_rights, reverse=true)),
        (name="Tradable (effort)", p=scenario(base0; policy="Tradable Use Rights",
            γ=γ_tradable_use_rights, ϕ=ϕ_tradable_use_rights, regulate=regulate_tradable_use_rights,
            policy_target=:effort, market_rate=0.05)),
        (name="Tradable (yield)", p=scenario(base0; policy="Tradable Use Rights",
            γ=γ_tradable_use_rights, ϕ=ϕ_tradable_use_rights, regulate=regulate_tradable_use_rights,
            policy_target=:yield, market_rate=0.05)),
        (name="Protected Area", p=scenario(base0; policy="Protected Area",
            γ=γ_protected_area, μ=μ_protected_area, regulate=regulate_protected_area, m=0.3)),
        (name="Economic Incentives", p=scenario(base0; policy="Economic Incentives",
            μ=μ_economic_incentive, γ=γ_economic_incentive, regulate=regulate_economic_incentive,
            policy_target=[:γ, :μ], policy_method=:multiplicative)),
        (name="Development", p=scenario(base0; policy="Development",
            μ=μ_development, γ=γ_development, regulate=regulate_development, μ_value=0.5, γ_value=0.5)),
    ]

    # --- Run scans ---
    println(rpad("Policy", 24), " | ", rpad("reg(RR)", 8), rpad("reg(WR)", 9), rpad("reg(TR)", 9), rpad("reg(ToR)", 10), rpad("reg(EH)", 9), rpad("reg(GI)min", 12), rpad("reg(Gov)", 10))
    println(repeat("-", 24 + 3 + 8 + 9 + 9 + 10 + 9 + 12 + 10))
    for pol in pols
        R = regulation_scan(pol.p; m)
        rr = round(R.r[R.oRR], digits=2)
        wr = round(R.r[R.oWR], digits=2)
        tr = round(R.r[R.oTR], digits=2)
        tor = round(R.r[R.oToR], digits=2)
        eh = round(R.r[R.oEH], digits=2)
        gi = round(R.r[R.oGI], digits=2)
        gv = round(R.r[R.oGov], digits=2)
        println(rpad(pol.name, 24), " | ", lpad(rr, 6), "  ", lpad(wr, 6), "  ", lpad(tr, 6), "   ", lpad(tor, 6), "   ", lpad(eh, 6), "    ", lpad(gi, 6), "     ", lpad(gv, 6))
    end
    nothing
end

"""
    policy_phase_plots(T; goal=:Gov, m=40, figsize=(1100, 800)) -> Figure

Given a T-like context (NamedTuple of Dists), sample it, build baseline
scenarios for each policy, optimize regulation w.r.t. `goal` using `regulation_scan`,
simulate at the chosen regulation, and return a multi-panel figure of phase plots.

Valid goals: :Gov, :ToR, :RR, :WR, :TR, :GI (min), :EH
"""
function policy_phase_plots(T; goal=:Gov, m=40, figsize=(1100, 800))
    # realize T and build baseline
    sample!(T, random=true)
    base0 = scenario(base(N=T.N); w̃=dist(data=T.w̃), ū=dist(data=T.ū))

    pols = [
        (name="Open Access", p=base0),
        (name="Exclusive Rights (lo)", p=scenario(base0; policy="Exclusive Use Rights",
            γ=γ_exclusive_use_rights, regulate=regulate_exclusive_use_rights, reverse=false)),
        (name="Exclusive Rights (hi)", p=scenario(base0; policy="Exclusive Use Rights",
            γ=γ_exclusive_use_rights, regulate=regulate_exclusive_use_rights, reverse=true)),
        (name="Tradable (effort)", p=scenario(base0; policy="Tradable Use Rights",
            γ=γ_tradable_use_rights, ϕ=ϕ_tradable_use_rights, regulate=regulate_tradable_use_rights,
            policy_target=:effort, market_rate=0.05)),
        (name="Tradable (yield)", p=scenario(base0; policy="Tradable Use Rights",
            γ=γ_tradable_use_rights, ϕ=ϕ_tradable_use_rights, regulate=regulate_tradable_use_rights,
            policy_target=:yield, market_rate=0.05)),
        (name="Protected Area", p=scenario(base0; policy="Protected Area",
            γ=γ_protected_area, μ=μ_protected_area, regulate=regulate_protected_area, m=0.3)),
        (name="Economic Incentives", p=scenario(base0; policy="Economic Incentives",
            μ=μ_economic_incentive, γ=γ_economic_incentive, regulate=regulate_economic_incentive,
            policy_target=[:γ, :μ], policy_method=:multiplicative)),
        (name="Development", p=scenario(base0; policy="Development",
            μ=μ_development, γ=γ_development, regulate=regulate_development, μ_value=0.5, γ_value=0.5)),
    ]

    # helper to choose goal index
    function pickidx(R)
        if goal == :Gov
            return R.oGov
        elseif goal == :ToR
            return R.oToR
        elseif goal == :RR
            return R.oRR
        elseif goal == :WR
            return R.oWR
        elseif goal == :TR
            return R.oTR
        elseif goal == :GI
            return R.oGI
        elseif goal == :EH
            return R.oEH
        else
            return R.oGov
        end
    end

    # run scans and sims
    scans = [regulation_scan(pol.p; m=m) for pol in pols]
    regs = [s.r[pickidx(s)] for s in scans]
    sols = [sim(pol.p; regulation=r) for (pol, r) in zip(pols, regs)]

    # plot grid 2 rows x 4 cols
    f = Figure(size=figsize)
    for (i, (pol, r, sol)) in enumerate(zip(pols, regs, sols))
        rrow = div(i - 1, 4) + 1
        ccol = mod(i - 1, 4) + 1
        # compute gender income % diff (symmetric percent difference)
        inc = incomes(sol)
        total = inc.total
        g = hasproperty(T.gender, :data) ? T.gender.data : T.gender
        midx = findall(g .== 0)
        fidx = findall(g .== 1)
        μm = isempty(midx) ? 0.0 : mean(total[midx])
        μf = isempty(fidx) ? 0.0 : mean(total[fidx])
        # Women as a percent of men (μF / μM * 100)
        pct_str = if μm == 0.0
            (μf == 0.0 ? "n/a" : "∞")
        else
            string(round(100 * μf / μm, digits=1), "%")
        end

        # Gini overall and for females
        g_all_str = begin
            s = sum(total)
            s <= 0 ? "n/a" : string(round(SED.gini(total), digits=2))
        end
        g_fem_str = begin
            if isempty(fidx)
                "n/a"
            else
                s = sum(total[fidx])
                s <= 0 ? "n/a" : string(round(SED.gini(total[fidx]), digits=2))
            end
        end
        ax = Axis(f[rrow, ccol], title="$(pol.name) @ reg=$(round(r, digits=2))")
        SED.phase_plot!(ax, sol)
        # overlay metrics in upper-right corner
        tot_sum = round(sum(total), digits=2)
        res_sum = round(sum(inc.resource), digits=2)
        label = "♀ \$ as % of ♂: $(pct_str)\nGini: all $(g_all_str) (♀ $(g_fem_str))\nTotal \$: $(tot_sum)\nResource \$: $(res_sum)"
        text!(ax, 0.25, 0.05; text=label, align=(:left, :bottom), color=:black)
    end
    f
end
