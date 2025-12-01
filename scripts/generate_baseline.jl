using Serialization
include("../SED.jl")
using .SED

# Define policies to test
# We use the same set as in regulation_scan_plot default
function get_test_policies(s)
    policies = [
        scenario(s, policy="Exclusive Use Rights", selector=:top),
        scenario(s, policy="Exclusive Use Rights", selector=:bottom),
        scenario(s, policy="Tradable Use Rights", policy_target=:effort, market_rate=0.05, buyer_bias=0.0),
        scenario(s, policy="Tradable Use Rights", policy_target=:yield, market_rate=0.05, buyer_bias=0.0),
        scenario(s, policy="Protected Area", m=0.3),
        scenario(s, policy="Economic Incentives", policy_target=[:cost], method=:taxation)
    ]
    return policies
end

function run_baseline()
    println("Generating baseline results...")
    s = SED.high_impact()
    policies = get_test_policies(s)

    results = Dict()

    for (i, p) in enumerate(policies)
        pol_name = p.policy
        println("  Running scan for policy: $pol_name (Index $i)")

        # Run regulation scan
        # We use standard weights
        rs = SED.regulation_scan(p)

        # Store key metrics
        # We store the vectors: RR, ToR, GI, Gov, and the r vector
        results[i] = Dict(
            "policy" => pol_name,
            "r" => rs.r,
            "RR" => rs.RR,
            "ToR" => rs.ToR,
            "GI" => rs.GI,
            "Gov" => rs.Gov
        )
    end

    println("Saving baseline to 'baseline_results.jls'...")
    serialize("baseline_results.jls", results)
    println("Done.")
end

run_baseline()
