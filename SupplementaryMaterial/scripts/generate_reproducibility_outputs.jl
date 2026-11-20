#!/usr/bin/env julia

using Printf
using SED
using Statistics

module Figure2Data
include(joinpath(@__DIR__, "..", "..", "manuscript", "figure2.jl"))
end

module Figure3Data
include(joinpath(@__DIR__, "..", "..", "manuscript", "figure3.jl"))
end

module Figure4Data
include(joinpath(@__DIR__, "..", "..", "manuscript", "helpers", "policy_scenarios.jl"))
end

const RESULTS_DIR = normpath(joinpath(@__DIR__, "..", "results"))

steady_index(sol) = max(1, length(sol.t) - 2)

function diagnostics(figure, panel, scenario, sol; sampling, seed="", baseline=nothing)
    p = sol.prob.p
    i = steady_index(sol)
    x = sol.u[i]
    t = sol.t[i]
    y = x[p.N+1]
    limits = p.limit(x, p, t)
    participation = mean(clamp.(x[1:p.N] ./ max.(limits, eps()), 0.0, 1.0))
    inc = incomes(x, p)
    change = isnothing(baseline) ? nothing : Figure4Data.income_changes(sol, baseline)
    resource_residual = abs(1.0 - y - sum(x[1:p.N]))

    market = if p.policy isa TradableUseRights
        tradable_market_diagnostics(sol; index=i)
    else
        nothing
    end

    return (;
        figure, panel, scenario, N=p.N, sampling, seed,
        resource=y,
        participation,
        total_pressure=sum(x[1:p.N]),
        resource_balance_residual=resource_residual,
        resource_income=sum(inc.resource),
        resource_revenue=sum(inc.resource_revenue),
        gross_resource_revenue=sum(inc.gross_resource_revenue),
        resource_rent=sum(inc.resource_rent),
        opportunity_cost=sum(inc.opportunity_cost),
        outside_income=sum(inc.outside_income),
        outside_income_0=sum(inc.outside_income_0),
        rights_transfer=sum(inc.rights_transfer),
        income_identity_residual=maximum(abs.(inc.total .- inc.outside_income_0 .- inc.resource_rent .- inc.extra)),
        total_income=sum(inc.total),
        gini=inc.gini,
        gini_change=isnothing(change) ? missing : change.gini_change,
        state_revenue=Figure4Data.public_revenue(sol),
        income_change=isnothing(change) ? missing : change.total_change,
        winner_share=isnothing(change) ? missing : change.winner_share,
        loser_share=isnothing(change) ? missing : change.loser_share,
        unchanged_share=isnothing(change) ? missing : change.unchanged_share,
        quota=market === nothing ? missing : market.quota,
        quota_use=market === nothing ? missing : market.quota_use,
        excess_use=market === nothing ? missing : market.excess_use,
        quota_violation=market === nothing ? missing : market.quota_violation,
        price=market === nothing ? missing : market.price,
        price_rate=market === nothing ? missing : market.price_rate,
        complementarity_error=market === nothing ? missing : market.complementarity_error,
        solver=string(sol.alg),
        solver_retcode=string(sol.retcode),
        final_time=t,
    )
end

function figure2_rows()
    ex = Figure2Data.intro_example()
    return [diagnostics("2", "A-C", "random dimensional population", ex.sol;
        sampling="random", seed="42")]
end

function figure3_rows()
    F = Figure3Data
    thresholds = F.ordered_thresholds(median=0.3, sigma=0.8)
    base = F.scenario(F.high_impact(N=F.FIG3_N);
        w̃=F.dist(data=thresholds),
        ū=F.dist(data=F.impact_profile()))
    rows = NamedTuple[]

    for (name, sigma) in (("wide thresholds", 0.8),
            ("narrow thresholds", 0.3), ("equal thresholds", 0.0))
        sol = F.sim(F.scenario(base;
            w̃=F.dist(median=0.5, sigma=sigma, distribution=F.LogNormal)))
        push!(rows, diagnostics("3", "a", name, sol; sampling="ordered"))
    end

    threshold_base = F.ordered_thresholds(median=0.50, sigma=0.52)
    for (name, values) in (("baseline thresholds", threshold_base),
            ("additive +0.30", threshold_base .+ 0.30),
            ("multiplicative x1.4", threshold_base .* 1.4))
        sol = F.sim(F.scenario(base; w̃=F.dist(data=values)))
        push!(rows, diagnostics("3", "b", name, sol; sampling="ordered"))
    end

    for (name, total) in (("low total impact", 1.02),
            ("baseline total impact", F.BASE_TOTAL_IMPACT),
            ("high total impact", 2.28))
        sol = F.sim(F.scenario(base; ū=F.dist(data=F.impact_profile(total))))
        push!(rows, diagnostics("3", "c", name, sol; sampling="ordered"))
    end

    for (name, orientation) in (("positive threshold-impact correlation", :positive),
            ("negative threshold-impact correlation", :negative))
        sol = F.sim(F.scenario(base;
            ū=F.dist(data=F.impact_profile(orientation=orientation))))
        push!(rows, diagnostics("3", "d", name, sol; sampling="ordered"))
    end

    for (name, alpha) in (("fast response", 0.05), ("slow response", 0.01))
        sol = F.sim(F.scenario(base; α=alpha), t_end=1000.0)
        push!(rows, diagnostics("3", "e", name, sol; sampling="ordered"))
    end
    return rows
end

function figure4_rows()
    rows, oa = Figure4Data.policy_rows()
    output = NamedTuple[
        diagnostics("4", "baseline", "open access", oa; sampling="ordered", baseline=oa)
    ]
    actors = NamedTuple[]
    for (panel, row) in enumerate(rows), variant in row.variants
        push!(output, diagnostics("4", string(panel), variant.label, variant.sol;
            sampling="ordered", baseline=oa))
        change = Figure4Data.income_changes(variant.sol, oa)
        theta = Figure4Data.distdata(oa.prob.p.w̃)
        potential = Figure4Data.distdata(oa.prob.p.ū)
        state = Figure4Data.steady_state(variant.sol)
        parameters = variant.sol.prob.p
        effective_threshold = parameters.cost(state, parameters, Figure4Data.steady_time(variant.sol))
        effective_potential = parameters.limit(state, parameters, Figure4Data.steady_time(variant.sol))
        for (rank, actor) in enumerate(change.order)
            push!(actors, (;
                policy=row.title, scenario=variant.label, actor, rank,
                baseline_exit_threshold=theta[actor],
                baseline_impact_potential=potential[actor],
                policy_exit_threshold=effective_threshold[actor],
                policy_impact_potential=effective_potential[actor],
                open_access_income=change.baseline.total[actor],
                policy_income=change.current.total[actor],
                income_change=change.delta[actor],
                resource_income_change=change.current.resource[actor] - change.baseline.resource[actor],
                resource_rent_change=change.current.resource_rent[actor] - change.baseline.resource_rent[actor],
                opportunity_cost_change=change.current.opportunity_cost[actor] - change.baseline.opportunity_cost[actor],
                outside_income_change=change.current.wages[actor] - change.baseline.wages[actor],
                transfer_change=change.current.trade[actor] - change.baseline.trade[actor],
                classification=change.winners[actor] ? "gain" : change.losers[actor] ? "loss" : "unchanged"))
        end
    end
    return (; scenarios=output, actors)
end

function csv_value(value)
    value === missing && return ""
    value isa AbstractFloat && return @sprintf("%.10g", value)
    text = string(value)
    return occursin(r"[,\"\n]", text) ? "\"" * replace(text, "\"" => "\"\"") * "\"" : text
end

function write_csv(path, rows)
    names = propertynames(first(rows))
    open(path, "w") do io
        println(io, join(string.(names), ","))
        for row in rows
            println(io, join((csv_value(getproperty(row, name)) for name in names), ","))
        end
    end
end

function latex_escape(text)
    plain = replace(string(text), "θᵢ" => "threshold")
    return replace(plain,
        "\\" => "\\textbackslash{}", "_" => "\\_", "%" => "\\%", "&" => "\\&")
end

function write_figure4_table(path, rows)
    selected = filter(row -> row.figure == "4", rows)
    open(path, "w") do io
        println(io, "\\begin{table}[htbp]")
        println(io, "\\centering")
        println(io, "\\caption{Numerical verification of Figure 4. Resource rent is retained harvest revenue minus forgone outside earnings, before rights transfers. Actor income excludes unrecycled royalty receipts, reported under State. Revenue, opportunity costs, outside earnings, transfers, and accounting and convergence residuals are recorded separately in the accompanying CSV.}")
        println(io, "\\label{tab:figure4_verification_sm}")
        println(io, "\\small")
        println(io, "\\begin{tabular}{@{}llrrrrr@{}}")
        println(io, "\\toprule")
        println(io, "Scenario & \$y^*\$ & \$P^*\$ & Rent & Actor income & State & Gini \\\\")
        println(io, "\\midrule")
        for row in selected
            @printf(io, "%s & %.3f & %.3f & %.3f & %.3f & %.3f & %.3f \\\\\n",
                latex_escape(row.scenario), row.resource, row.participation,
                row.resource_rent, row.total_income, row.state_revenue, row.gini)
        end
        println(io, "\\bottomrule")
        println(io, "\\end{tabular}")
        println(io, "\\end{table}")
    end
end

function main()
    mkpath(RESULTS_DIR)
    policies = figure4_rows()
    rows = vcat(figure2_rows(), figure3_rows(), policies.scenarios)
    write_csv(joinpath(RESULTS_DIR, "main_figure_verification.csv"), rows)
    write_csv(joinpath(RESULTS_DIR, "figure4_income_changes.csv"), policies.actors)
    write_figure4_table(joinpath(RESULTS_DIR, "figure4_verification_table.tex"), rows)
    println("Wrote reproducibility outputs to ", RESULTS_DIR)
end

main()
