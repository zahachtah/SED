include("../SED.jl")
using .SED
using CairoMakie
using Distributions
using Statistics

# Reconstruct T from user context
T = (
    N=200,
    health=dist(mean=0, sigma=2.0, distribution=Normal, dependency_fun="1/(1+exp(-2-independent))"),
    gender=dist(mean=0.5, distribution=Bernoulli, random=true),
    parental=dist(min=0.1, max=1.0, distribution=LogNormal),
    time=dist(dependency_fun="health*(1-gender*0.5)*independent", min=0, max=1),
    efficiency=dist(min=0.015, max=0.2, dependency_fun="1*parental*(1-gender*0.2)*independent", normalize=false),
    AIO=dist(min=0.1, max=1.6, distribution=LogNormal, dependency_fun="0.02*parental*(1-gender*0.3)*independent"),
    K=2.0,
    ū=dist(min=-0.1, max=0.1, dependency_fun="time*efficiency"),
    w̃=dist(min=-0.1, max=0.1, dependency_fun="(AIO ./ efficiency) .+ independent"),
    α=dist(min=0.1, max=0.1, distribution=Uniform)
)

println("Running reproduction...")
try
    # Create scenario with historical_use_rights=true
    # The user used regulation_scan_plot which uses default policies, one of which has historical_use_rights=true
    # We can just try to run that specific policy directly to isolate the crash.

    s = scenario(T, policy="Tradable Use Rights", policy_target=:effort, market_rate=0.05, buyer_bias=0.0, historical_use_rights=true)

    # Try to regulate it (which triggers the historical calculation)
    # regulation_scan calls regulate(s, f)

    println("Calling regulate(s, 0.5)...")
    s_reg = SED.regulate(s, 0.5)
    println("Success!")

catch e
    println("Caught error: $e")
    if isa(e, BoundsError)
        println("BoundsError confirmed.")
        # Print stacktrace if possible, but simple print is enough for now
    end
    rethrow(e)
end
