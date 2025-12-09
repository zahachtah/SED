include("../SED.jl")
using .SED
using CairoMakie

# Run regulation_scan_plot with heatmap=true
println("Running regulation_scan_plot(heatmap=true)...")
try
    f = SED.regulation_scan_plot(heatmap=true)
    save("test_heatmap_style.png", f)
    println("Success! Saved test_heatmap_style.png")
catch e
    println("Error: $e")
    rethrow(e)
end
