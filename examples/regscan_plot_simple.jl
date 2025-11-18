if !isdefined(Main, :SED)
    error("Load SED first: include(\"SED.jl\"); using .SED")
end

using .SED
using CairoMakie

"""
Convenience wrapper that forwards to `SED.regulation_scan_plot`.
Kept for backwards compatibility with existing scripts/notebooks.
"""
regscan_simple(; kwargs...) = SED.regulation_scan_plot(; kwargs...)

if abspath(PROGRAM_FILE) == @__FILE__
    fig = regscan_simple()
    save(joinpath(@__DIR__, "figures", "regscan_simple.png"), fig)
    display(fig)
end
