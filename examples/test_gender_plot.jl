include("../SED.jl")
using .SED
using CairoMakie
using Distributions

# Define T context with gender
T = (
    gender=dist(mean=0.5, distribution=Bernoulli, random=true),
)

# Run regulation_scan_plot with showgender=true and historical policy
println("Running regulation_scan_plot(showgender=true)...")
try
    # Create a valid base scenario
    s_base = SED.high_impact()

    # Define T context with gender (and other fields from s_base to be safe)
    T = (; s_base..., gender=dist(mean=0.5, distribution=Bernoulli, random=true))

    # Define policies using the valid T
    policies = [
        SED.scenario(T, policy="Tradable Use Rights", policy_target=:effort, market_rate=0.05, buyer_bias=0.0, historical_use_rights=true)
    ]

    # Pass Tcontext explicitly
    f = SED.regulation_scan_plot(showgender=true, Tcontext=T, policies=policies)
    save("test_gender_plot_historical.png", f)
    println("Success! Saved test_gender_plot_historical.png")
catch e
    println("Error: $e")
    rethrow(e)
end
