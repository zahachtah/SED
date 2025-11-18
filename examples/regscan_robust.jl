#!/usr/bin/env julia
# Robust regulation scan with improved ODE solver settings and error handling

if !isdefined(Main, :SED)
    include(joinpath(@__DIR__, "..", "SED.jl"))
end
const S = Main.SED

using CairoMakie
using ColorSchemes
using Printf

"""
    regscan_robust(; scenario_type=:base, N=50, solver_kwargs=Dict(),
                   test_individual=false, save_diagnostics=true)

Robust regulation scan that handles ODE solver instabilities.

# Arguments
- `scenario_type`: `:base` or `:high_impact` scenario type
- `N`: Number of agents (smaller N = more stable)
- `solver_kwargs`: Additional solver parameters for stability
- `test_individual`: Test each policy individually first
- `save_diagnostics`: Save diagnostic information on failures

# Returns
- Figure with policy comparison plots, or error diagnostics
"""
function regscan_robust(; scenario_type=:base, N=50, solver_kwargs=Dict(),
                       test_individual=false, save_diagnostics=true)

    # Create scenario with specified type
    s = if scenario_type == :high_impact
        S.high_impact(N=N)
    elseif scenario_type == :base
        S.base(N=N)
    else
        error("Unknown scenario_type: $scenario_type. Use :base or :high_impact")
    end

    println("Testing regscan with $(scenario_type) scenario, N=$N")

    # Default robust solver settings for stiff problems
    default_solver_kwargs = Dict(
        :solver => :Rosenbrock23,  # Good for moderately stiff problems
        :reltol => 1e-6,
        :abstol => 1e-8,
        :maxiters => 100000,
        :dtmax => 0.1
    )
    solver_settings = merge(default_solver_kwargs, solver_kwargs)

    # Helper functions for EUR selection
    getdata(v) = hasproperty(v, :data) ? v.data : v
    sel_top = (w̃, n) -> sortperm(getdata(w̃), rev=true)[1:n]
    sel_bot = (w̃, n) -> sortperm(getdata(w̃))[1:n]

    # Build policies
    policies = [
        S.with_policy(s; S.exclusive_use_rights_kit(; selector=sel_top)...),
        S.with_policy(s; S.exclusive_use_rights_kit(; selector=sel_bot)...),
        S.with_policy(s; S.tradable_use_rights_kit(; target=:effort, market_rate=0.05)...),
        S.with_policy(s; S.tradable_use_rights_kit(; target=:yield, market_rate=0.05)...),
        S.with_policy(s; S.protected_area_kit(; m=0.3)...),
        S.with_policy(s; S.protected_area_kit(; m=0.5)...)
    ]

    policy_names = [
        "EUR High w̃ excluded",
        "EUR Low w̃ excluded",
        "TUR Effort-based",
        "TUR Yield-based",
        "Protected Area m=0.3",
        "Protected Area m=0.5"
    ]

    # Test individual policies first if requested
    if test_individual
        println("Testing individual policies...")
        for (i, (policy, name)) in enumerate(zip(policies, policy_names))
            try
                rs_test = S.regulation_scan(policy; warmstart=:none,
                                         solver_kwargs...)
                println("✓ Policy $i ($name): $(length(rs_test.r)) points")
                println("  ToR range: $(round(minimum(rs_test.ToR), digits=3)) to $(round(maximum(rs_test.ToR), digits=3))")
            catch e
                println("✗ Policy $i ($name) failed: $e")
                if save_diagnostics
                    save_policy_diagnostics(policy, name, i, e)
                end
            end
        end
        println("")
    end

    # Run regulation scans with error handling
    println("Running regulation scans...")
    RS = Vector{Any}(undef, length(policies))
    success_count = 0

    for (i, (policy, name)) in enumerate(zip(policies, policy_names))
        try
            RS[i] = S.regulation_scan(policy;
                                    kR=0.5, kT=1.0, kG=-0.2, kE=0.0,
                                    warmstart=:chain,
                                    solver_kwargs...)

            # Validate results
            if any(isnan, RS[i].ToR) || any(isinf, RS[i].ToR)
                throw(ErrorException("NaN or Inf values in results"))
            end

            println("✓ Policy $i ($name): Success")
            success_count += 1

        catch e
            println("✗ Policy $i ($name): Failed - $e")
            RS[i] = nothing

            if save_diagnostics
                save_policy_diagnostics(policy, name, i, e)
            end
        end
    end

    println("Successfully completed $success_count/$(length(policies)) policies")

    if success_count == 0
        return create_failure_report(scenario_type, N, policies, policy_names)
    end

    # Create visualization
    return create_robust_visualization(RS, policy_names, success_count)
end

function save_policy_diagnostics(policy, name, index, error)
    """Save diagnostic information for failed policy"""
    filename = "policy_$(index)_diagnostics.txt"
    open(filename, "w") do f
        println(f, "Policy Diagnostic Report")
        println(f, "=======================")
        println(f, "Policy: $name (index $index)")
        println(f, "Error: $error")
        println(f, "Time: $(now())")
        println(f, "\nPolicy parameters:")
        for (k, v) in pairs(policy)
            println(f, "  $k: $v")
        end
    end
    println("  Diagnostics saved to $filename")
end

function create_failure_report(scenario_type, N, policies, policy_names)
    """Create a diagnostic figure when all policies fail"""
    fig = Figure(size=(800, 600))

    ax = Axis(fig[1, 1],
             title="Regulation Scan Failed - All Policies Unstable",
             xlabel="Diagnosis", ylabel="")

    hidedecorations!(ax)
    hidespines!(ax)

    text!(ax, 0.1, 0.8,
          text="Regulation scan failed for scenario: $(scenario_type)\n" *
               "N = $N\n\n" *
               "All $(length(policies)) policies encountered numerical instability.\n\n" *
               "Recommendations:\n" *
               "• Try smaller N (e.g., N=25)\n" *
               "• Use base scenario instead of high_impact\n" *
               "• Check solver settings\n" *
               "• Examine individual policy diagnostics",
          space=:relative, fontsize=12)

    return fig
end

function create_robust_visualization(RS, policy_names, success_count)
    """Create visualization with handling for failed policies"""

    # Filter successful results
    successful_indices = [i for i in 1:length(RS) if RS[i] !== nothing]
    successful_RS = [RS[i] for i in successful_indices]
    successful_names = [policy_names[i] for i in successful_indices]

    outcomes = [:RR, :ToR, :GI, :EH, :RI, :Gov]
    outcome_labels = Dict(
        :RR => "Resource\nRevenues",
        :ToR => "Total\nRevenues",
        :GI => "Gini\nIndex",
        :EH => "Ecological\nHealth",
        :RI => "Regulatory\nImpact",
        :Gov => "Governance\nGoal"
    )

    fig = Figure(size=(1200, 800))

    # Title
    Label(fig[0, :], text="Robust Regulation Scan Results ($success_count policies)",
          fontsize=16, font=:bold)

    # Create subplots for each outcome
    for (j, outcome) in enumerate(outcomes)
        ax = Axis(fig[j, 1],
                 title=outcome_labels[outcome],
                 xlabel=j == length(outcomes) ? "Regulation Level" : "",
                 ylabel="Value")

        colors = ColorSchemes.tab10[1:length(successful_RS)]

        for (i, (rs, name)) in enumerate(zip(successful_RS, successful_names))
            # Plot regulation scan curve
            lines!(ax, rs.r, getfield(rs, outcome),
                  color=colors[i], linewidth=2, label=name)

            # Mark optimum
            opt_symbol = Symbol("o" * String(outcome))
            if hasproperty(rs, opt_symbol)
                opt_idx = getfield(rs, opt_symbol)
                scatter!(ax, [rs.r[opt_idx]], [getfield(rs, outcome)[opt_idx]],
                        color=colors[i], markersize=8)
            end
        end

        # Add legend to first plot
        if j == 1
            axislegend(ax, position=:rt)
        end
    end

    # Add summary statistics
    stats_ax = Axis(fig[:, 2], title="Summary Statistics")
    hidedecorations!(stats_ax)
    hidespines!(stats_ax)

    stats_text = "Successful Policies: $success_count/$(length(policy_names))\n\n"

    for (i, (rs, name)) in enumerate(zip(successful_RS, successful_names))
        stats_text *= "$name:\n"
        stats_text *= @sprintf("  ToR optimum: %.3f at reg=%.2f\n",
                               rs.ToR[rs.oToR], rs.r[rs.oToR])
        stats_text *= @sprintf("  Gov optimum: %.3f at reg=%.2f\n",
                               rs.Gov[rs.oGov], rs.r[rs.oGov])
        stats_text *= "\n"
    end

    text!(stats_ax, 0.05, 0.95, text=stats_text,
          space=:relative, fontsize=10, align=(:left, :top))

    return fig
end

"""
    test_solver_stability(; N=25)

Quick test of different solver configurations for stability.
"""
function test_solver_stability(; N=25)
    println("Testing solver stability with N=$N...")

    solvers = [
        (:Rosenbrock23, "Rosenbrock23 (moderate stiff)"),
        (:Rodas4, "Rodas4 (stiff)"),
        (:KenCarp4, "KenCarp4 (stiff/nonstiff)"),
        (:Tsit5, "Tsit5 (nonstiff default)")
    ]

    s_base = S.base(N=N)
    test_policy = S.with_policy(s_base; S.protected_area_kit(m=0.3)...)

    for (solver, name) in solvers
        try
            rs = S.regulation_scan(test_policy; solver=solver, warmstart=:none)
            println("✓ $name: Success (ToR range: $(round(minimum(rs.ToR), digits=3))-$(round(maximum(rs.ToR), digits=3)))")
        catch e
            println("✗ $name: Failed - $e")
        end
    end
end

# Convenience functions for different scenarios
regscan_base_robust(; kwargs...) = regscan_robust(; scenario_type=:base, kwargs...)
regscan_high_impact_robust(; kwargs...) = regscan_robust(; scenario_type=:high_impact, kwargs...)

# Export functions if this is run as a script
if abspath(PROGRAM_FILE) == @__FILE__
    println("Running robust regscan test...")

    # Test solver stability first
    test_solver_stability()
    println()

    # Test with base scenario
    fig_base = regscan_base_robust(N=25, test_individual=true)
    save("regscan_base_robust.png", fig_base)
    println("Base scenario results saved to regscan_base_robust.png")

    # Test with high_impact scenario
    fig_high = regscan_high_impact_robust(N=25, test_individual=true)
    save("regscan_high_impact_robust.png", fig_high)
    println("High impact scenario results saved to regscan_high_impact_robust.png")
end
