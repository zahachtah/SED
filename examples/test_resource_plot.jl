include("../SED.jl")
using .SED
using CairoMakie

# Run regulation_scan_plot with resource=true
println("Running regulation_scan_plot(resource=true)...")
try
    f = SED.regulation_scan_plot(resource=true)
    save("test_resource_plot.png", f)
    println("Success! Saved test_resource_plot.png")
catch e
    println("Error: $e")
    rethrow(e)
end

# Run with both heatmap and resource
println("Running regulation_scan_plot(resource=true, heatmap=true)...")
try
    f = SED.regulation_scan_plot(resource=true, heatmap=true)
    save("test_resource_heatmap_plot.png", f)
    println("Success! Saved test_resource_heatmap_plot.png")
catch e
    println("Error: $e")
    rethrow(e)
end
