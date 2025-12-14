include("../SED.jl")
using .SED
using CairoMakie

# Run regulation_scan_plot to verify no errors
println("Running regulation_scan_plot with normalization...")
try
    f = SED.regulation_scan_plot()
    save("test_normalization.png", f)
    println("Success! Saved test_normalization.png")
catch e
    println("Error: $e")
    rethrow(e)
end
