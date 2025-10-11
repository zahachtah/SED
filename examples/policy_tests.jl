#!/usr/bin/env julia
# Quick policy validation script across major instruments

using Random
Random.seed!(123)

if !isdefined(Main, :SED)
    include(joinpath(@__DIR__, "..", "SED.jl"))
end
const S = Main.SED

function make_T(N=100)
    (
        N=N,
        health=S.dist(mean=0, sigma=2.0, distribution=Normal, dependency_fun="1/(1+exp(-2-independent))"),
        gender=S.dist(mean=0.5, distribution=Bernoulli, random=true),
        parental=S.dist(min=0.1, max=1.0, distribution=LogNormal),
        time=S.dist(dependency_fun="health*(1-gender*0.5)*independent", min=0, max=1),
        efficiency=S.dist(min=0.015, max=0.2, dependency_fun="1*parental*(1-gender*0.2)*independent", normalize=false),
        opportunities=S.dist(min=0.1, max=1.6, distribution=LogNormal, dependency_fun="0.02*parental*(1-gender*0.5)*independent"),
        K=2.0,
        ū=S.dist(min=-0.1, max=0.1, dependency_fun="time*efficiency"),
        w̃=S.dist(min=-0.1, max=0.1, dependency_fun="(opportunities ./ efficiency) .+ independent"),
        α=S.dist(min=0.1, max=0.1, distribution=Uniform)
    )
end

function baseline_from_T(T)
    S.sample!(T, random=true)
    S.scenario(S.base(N=T.N);
        w̃=S.dist(data=T.w̃),
        ū=S.dist(data=T.ū))
end

function run_policy(name::String, s; regulation=0.3; kwargs...)
    sol = S.sim(s; regulation)
    inc = S.incomes(sol)
    println("[", rpad(name, 24), "] y*=" , round(sol.u[end][end], digits=3),
            "  RR=", round(sum(inc.resource), digits=3),
            "  ToR=", round(sum(inc.total), digits=3),
            "  G=", round(inc.gini, digits=3))
    return sol
end

function main()
    T = make_T(100)
    base = baseline_from_T(T)

    # Open Access (baseline)
    run_policy("Open Access", base; regulation=0.0)

    # Exclusive Use Rights (low vs high incentive groups)
    eur_lo = S.scenario(base; policy="Exclusive Use Rights",
        γ=S.γ_exclusive_use_rights,
        regulate=S.regulate_exclusive_use_rights,
        reverse=false)
    run_policy("Exclusive Rights (lo)", eur_lo; regulation=0.3)

    eur_hi = S.scenario(base; policy="Exclusive Use Rights",
        γ=S.γ_exclusive_use_rights,
        regulate=S.regulate_exclusive_use_rights,
        reverse=true)
    run_policy("Exclusive Rights (hi)", eur_hi; regulation=0.3)

    # Tradable Use Rights (effort and yield targets)
    tur_eff = S.scenario(base; policy="Tradable Use Rights",
        γ=S.γ_tradable_use_rights,
        ϕ=S.ϕ_tradable_use_rights,
        regulate=S.regulate_tradable_use_rights,
        policy_target=:effort, market_rate=0.05)
    run_policy("Tradable (effort)", tur_eff; regulation=0.3)

    tur_yield = S.scenario(base; policy="Tradable Use Rights",
        γ=S.γ_tradable_use_rights,
        ϕ=S.ϕ_tradable_use_rights,
        regulate=S.regulate_tradable_use_rights,
        policy_target=:yield, market_rate=0.05)
    run_policy("Tradable (yield)", tur_yield; regulation=0.3)

    # Protected Area (single pop)
    pa = S.scenario(base; policy="Protected Area",
        γ=S.γ_protected_area,
        μ=S.μ_protected_area,
        regulate=S.regulate_protected_area,
        m=0.3)
    run_policy("Protected Area", pa; regulation=0.3)

    # Economic Incentives
    econ = S.scenario(base; policy="Economic Incentives",
        μ=S.μ_economic_incentive,
        γ=S.γ_economic_incentive,
        regulate=S.regulate_economic_incentive,
        policy_target=[:γ, :μ], policy_method=:multiplicative)
    run_policy("Economic Incentives", econ; regulation=0.3)

    # Development
    dev = S.scenario(base; policy="Development",
        μ=S.μ_development,
        γ=S.γ_development,
        regulate=S.regulate_development,
        μ_value=0.5, γ_value=0.5)
    run_policy("Development", dev; regulation=0.3)

    println("\nScan example (Tradable effort):")
    R = S.regulation_scan(tur_eff; m=25)
    println("  max ToR@reg=", round(R.r[R.oToR], digits=2), "  ToR=", round(R.ToR[R.oToR], digits=3))
end

abspath(PROGRAM_FILE) == @__FILE__ && main()

