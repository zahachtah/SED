using SED
using Distributions
using Test

# 1. Define Distributions
# We want w̃ to depend on some "quality" factor.

dist_spec = (
    N=10,
    α=0.1,

    # Auxiliary distribution (Independent)
    quality=dist(min=0.5, max=1.5, distribution=Uniform),

    # w̃ depends on quality: w̃ = 0.5 * quality + noise
    # We use @dependent macro
    w̃=dist(dependency=SED.@dependent((quality) -> 0.5 .* quality .+ independent),
        distribution=Normal, mean=0, sigma=0.1),

    # ū is independent
    ū=dist(mean=1.0, sigma=0.1, distribution=Normal, normalize=true)
)

# 2. Create Scenario
# scenario() adds default policies (Open Access) and helper functions (γ, μ, etc.)
scen = scenario(dist_spec)

println("Scenario created.")
println("w̃ source: ", typeof(scen.w̃.source))
println("w̃ dependency: ", typeof(scen.w̃.dependency))

# 3. Run Simulation
# sim() will sample distributions if they are empty
println("Running simulation...")
sol = sim(scen, t_end=50.0)

println("Simulation complete.")
println("Final Resource (y): ", sol[scen.N+1, end])
println("Final Effort (u): ", sum(sol[1:scen.N, end]))

# Verify dependency worked
# w̃ data should be populated
println("w̃ data sample: ", scen.w̃.data[1:5])
println("quality data sample: ", scen.quality.data[1:5])

# Check correlation (should be positive)
using Statistics
corr = cor(scen.w̃.data, scen.quality.data)
println("Correlation between w̃ and quality: ", corr)

if corr > 0.5
    println("SUCCESS: Dependency works (correlation > 0.5)")
else
    println("WARNING: Correlation low ($corr)")
end
