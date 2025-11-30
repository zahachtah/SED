using SED
using Distributions
using Test

# 1. Define Base Scenario
dist_spec = (
    N=10,
    w̃=dist(mean=0.5, sigma=0.1, distribution=Normal),
    ū=dist(mean=1.0, sigma=0.1, distribution=Normal, normalize=true)
)
scen = scenario(dist_spec)
SED.sample!(scen) # Populate data

println("Base scenario created.")

# 2. Apply Policy 1: Economic Incentive (Additive Tax)
# Adds 0.1 to γ
pol1 = economic_incentives_kit(policy_target=[:γ], policy_method=:additive)
scen_p1 = with_policy(scen; pol1...)
scen_p1 = scen_p1.regulate(scen_p1, 0.1) # Apply regulation f=0.1

# 3. Apply Policy 2: Development
# Adds t/1000 * 0.5 to γ (if γ_value=0.5)
pol2 = development_kit(γ_value=0.5, μ_value=0.0)
scen_p2 = with_policy(scen_p1; pol2...)
# Note: regulate() overwrites. If we call regulate for pol2, it might mess up pol1's regulation if they share 'regulation' param.
# In this refactor, 'regulation' is a shared parameter in the scenario NamedTuple.
# Both policies use 'p.regulation'.
# This is a limitation of the current parameter sharing, but for this test we assume they share f=0.1.

# 4. Verify Composition
# We check γ at t=0 and t=100.

# t=0
# Base w̃ ≈ 0.5
# Pol1: +0.1
# Pol2: +0 (at t=0)
# Expected: 0.6

# t=100
# Base w̃ ≈ 0.5
# Pol1: +0.1
# Pol2: + 0.1 * 100/1000 * 0.5 = 0.005
# Expected: 0.605

# Let's inspect γ directly using master_γ
x = zeros(scen.N) # dummy state
t0 = 0.0
t100 = 100.0

γ0 = scen_p2.γ(x, scen_p2, t0)
γ100 = scen_p2.γ(x, scen_p2, t100)

println("γ at t=0 (first agent): ", γ0[1])
println("γ at t=100 (first agent): ", γ100[1])

base_val = scen.w̃.data[1]
expected_0 = base_val + 0.1
expected_100 = base_val + 0.1 + (0.1 * 100 / 1000 * 0.5)

println("Expected t=0: ", expected_0)
println("Expected t=100: ", expected_100)

@test isapprox(γ0[1], expected_0, atol=1e-5)
@test isapprox(γ100[1], expected_100, atol=1e-5)

if isapprox(γ0[1], expected_0, atol=1e-5) && isapprox(γ100[1], expected_100, atol=1e-5)
    println("SUCCESS: Policies composed correctly.")
else
    println("FAILURE: Composition mismatch.")
end
