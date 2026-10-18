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

function diagnostics(figure, panel, scenario, sol; sampling, seed="")
    p = sol.prob.p
    i = steady_index(sol)
    x = sol.u[i]
    t = sol.t[i]
    y = x[p.N+1]
    limits = p.limit(x, p, t)
    participation = mean(clamp.(x[1:p.N] ./ max.(limits, eps()), 0.0, 1.0))
    inc = incomes(x, p)
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
        total_income=sum(inc.total),
        gini=inc.gini,
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
        diagnostics("4", "baseline", "open access", oa; sampling="ordered")
    ]
    for (panel, row) in enumerate(rows), variant in row.variants
        push!(output, diagnostics("4", string(panel), variant.label, variant.sol;
            sampling="ordered"))
    end
    return output
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
        println(io, "\\caption{Numerical verification of the Figure 4 scenarios. Residuals are evaluated at the reported final state.}")
        println(io, "\\label{tab:figure4_verification_sm}")
        println(io, "\\small")
        println(io, "\\begin{tabular}{@{}llrrrrr@{}}")
        println(io, "\\toprule")
        println(io, "Scenario & \$y^*\$ & \$P^*\$ & Resource income & Total income & Gini & Excess use \\\\")
        println(io, "\\midrule")
        for row in selected
            excess = row.excess_use === missing ? "--" : @sprintf("%.2e", row.excess_use)
            @printf(io, "%s & %.3f & %.3f & %.3f & %.3f & %.3f & %s \\\\\n",
                latex_escape(row.scenario), row.resource, row.participation,
                row.resource_income, row.total_income, row.gini, excess)
        end
        println(io, "\\bottomrule")
        println(io, "\\end{tabular}")
        println(io, "\\end{table}")
    end
end

function main()
    mkpath(RESULTS_DIR)
    rows = vcat(figure2_rows(), figure3_rows(), figure4_rows())
    write_csv(joinpath(RESULTS_DIR, "main_figure_verification.csv"), rows)
    write_figure4_table(joinpath(RESULTS_DIR, "figure4_verification_table.tex"), rows)
    println("Wrote reproducibility outputs to ", RESULTS_DIR)
end

main()
