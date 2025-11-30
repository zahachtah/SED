#!/usr/bin/env julia
# Build all figures referenced by README and docs in one go.

using Random
Random.seed!(1234)

# Load package
include(joinpath(@__DIR__, "..", "SED.jl"))
using .SED

# Ensure plotting backend is ready
try
    @eval begin
        using CairoMakie
        CairoMakie.activate!()
    end
catch err
    @warn "CairoMakie not available; plot scripts may fail" err
end

function run_script(path::AbstractString)
    println("-- running: ", path)
    try
        include(path)
    catch err
        @warn "script failed" path err
    end
end

root = normpath(joinpath(@__DIR__, ".."))

# README figures
run_script(joinpath(root, "examples", "readme_figures.jl"))

# Warm-start scan figure
run_script(joinpath(root, "examples", "warmstart_scan_figure.jl"))

# Manuscript figures
run_script(joinpath(root, "manuscript", "figures.jl"))

println("All done. Check examples/figures and manuscript/figures.")

