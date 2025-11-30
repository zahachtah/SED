using SED
using Test
using Statistics
using Distributions

@testset "Solver Instability Reproduction" begin
    # Reproduce T
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

    # Sample T (important because AIO fix affects values)
    SED.sample!(scenario(T))

    # Check w values
    w_vals = T.w̃.data
    println("Min w: ", minimum(w_vals))
    println("Max w: ", maximum(w_vals))
    println("Negative w count: ", count(x -> x < 0, w_vals))

    println("Running OA simulation...")
    oa_sol = sim(scenario(T))
    println("OA Retcode: ", oa_sol.retcode)

    # Apply policy with historical_use_rights=true
    s1 = with_policy(scenario(T); tradable_use_rights_kit(target=:effort, buyer_bias=1.0, historical_use_rights=true)...)

    println("Running simulation (Original)...")
    sol = sim(s1, regulation=0.5)
    println("Original Retcode: ", sol.retcode)
    println("Original t_end: ", sol.t[end])

    println("\nRunning simulation (Lower Market Rate)...")
    s2 = with_policy(scenario(T); tradable_use_rights_kit(target=:effort, buyer_bias=1.0, historical_use_rights=true, market_rate=0.001)...)
    sol2 = sim(s2, regulation=0.5)
    println("Lower Rate Retcode: ", sol2.retcode)
    println("Lower Rate t_end: ", sol2.t[end])

    println("\nRunning simulation (No Bias)...")
    s3 = with_policy(scenario(T); tradable_use_rights_kit(target=:effort, buyer_bias=0.0, historical_use_rights=true)...)
    sol3 = sim(s3, regulation=0.5)
    println("No Bias Retcode: ", sol3.retcode)
    println("No Bias t_end: ", sol3.t[end])
end
