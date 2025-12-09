include("../SED.jl")
using .SED
using CairoMakie

println("Creating SEDist...")
# Create a distribution
d = dist(mean=2.0, sigma=0.5, distribution=Normal)
sample!(d, 1000)

println("Plotting SEDist...")
try
    f = plot(d)
    save("test_sdist_plot.png", f)
    println("Success! Saved test_sdist_plot.png")
catch e
    println("Error: $e")
    rethrow(e)
end
