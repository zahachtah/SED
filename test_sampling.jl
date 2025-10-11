# Test script to demonstrate sampling behavior differences in SED distributions

using Statistics
include("SED.jl")
using .SED

println("=== SED Sampling Behavior Test ===\n")

# Test 1: Create distribution from min/max bounds
println("1. Distribution from min/max bounds:")
b = dist(min=0.1, max=14, distribution=LogNormal)
println("b = ", b)

# Get theoretical parameters
theo_median_b = getmedian(b)
theo_sigma_b = getsigma(b)
println("Theoretical median: ", theo_median_b)
println("Theoretical sigma: ", theo_sigma_b)
println("Underlying LogNormal parameters: μ=", b.distribution.μ, ", σ=", b.distribution.σ)
println()

# Test 2: Create equivalent distribution from median/sigma
println("2. Equivalent distribution from median/sigma:")
a = dist(median=theo_median_b, sigma=theo_sigma_b, distribution=LogNormal)
println("a = ", a)
println("Underlying LogNormal parameters: μ=", a.distribution.μ, ", σ=", a.distribution.σ)
println()

# Test 3: Sample both distributions
println("3. Sampling both distributions (N=100):")
sample!(a, 100)
sample!(b, 100)

# Compare sampled statistics
println("Distribution a (median/sigma parameterization):")
println("  Sampled median: ", getmedian(a, sampled=true))
println("  Sampled sigma:  ", getsigma(a, sampled=true))
println("  Data range: [", minimum(a.data), ", ", maximum(a.data), "]")

println("Distribution b (min/max parameterization):")
println("  Sampled median: ", getmedian(b, sampled=true))
println("  Sampled sigma:  ", getsigma(b, sampled=true))
println("  Data range: [", minimum(b.data), ", ", maximum(b.data), "]")
println()

# Test 4: Show the difference in sampling methods
println("4. Understanding the sampling difference:")
println("Distribution a samples from quantiles: ", range(1 / 100, stop=1 - 1 / 100, length=100)[1:5], "...")
println("Distribution b samples from quantiles: ", range(0.01, stop=0.99, length=100)[1:5], "...")
println()

# Test 5: Create truly different distributions
println("5. Creating truly different distributions:")

# Create a high-variance version
c = dist(min=0.05, max=20, distribution=LogNormal)
sample!(c, 100)

# Create a low-variance version
d = dist(min=0.2, max=8, distribution=LogNormal)
sample!(d, 100)

println("High variance distribution c:")
println("  Theoretical median: ", getmedian(c))
println("  Theoretical sigma:  ", getsigma(c))
println("  Sampled median:     ", getmedian(c, sampled=true))
println("  Sampled sigma:      ", getsigma(c, sampled=true))

println("Low variance distribution d:")
println("  Theoretical median: ", getmedian(d))
println("  Theoretical sigma:  ", getsigma(d))
println("  Sampled median:     ", getmedian(d, sampled=true))
println("  Sampled sigma:      ", getsigma(d, sampled=true))
println()

# Test 6: Random sampling vs deterministic
println("6. Random vs deterministic sampling:")

e = dist(min=0.1, max=14, distribution=LogNormal, random=true)
f = dist(min=0.1, max=14, distribution=LogNormal, random=false)

sample!(e, 100)
sample!(f, 100)

println("Random sampling (e):")
println("  Sampled median: ", getmedian(e, sampled=true))
println("  Sampled sigma:  ", getsigma(e, sampled=true))

println("Deterministic sampling (f):")
println("  Sampled median: ", getmedian(f, sampled=true))
println("  Sampled sigma:  ", getsigma(f, sampled=true))
println()

# Test 7: Demonstrate the key insight
println("7. Key insight - Why a and b give similar results:")
println("When you create distribution 'a' using getmedian(b) and getsigma(b),")
println("you're recreating the same underlying LogNormal distribution!")
println("The slight differences in sampled values come from:")
println("  - Different quantile ranges used for sampling")
println("  - Distribution b: samples between quantiles 0.01-0.99")
println("  - Distribution a: samples between quantiles 0.01-0.99 (approx)")
println()
println("To get meaningfully different sampled statistics, you need:")
println("  1. Different underlying distribution parameters, OR")
println("  2. Random sampling instead of deterministic sampling")
