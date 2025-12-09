include("../SED.jl")
using .SED
using Distributions

println("Creating scenario with sigma=0.0...")
s = SED.high_impact(sigma=0.0)
SED.sample!(s)

println("s.ū source: ", s.ū.source)
println("s.ū data extrema: ", extrema(s.ū.data))

if s.ū.source isa SED.RandomSource && s.ū.source.dist isa Uniform
    println("BUG CONFIRMED: Source is Uniform despite sigma=0.0")
else
    println("Source seems correct: ", s.ū.source)
end

if std(s.ū.data) > 1e-6
    println("BUG CONFIRMED: Data has variance despite sigma=0.0")
else
    println("Data is constant.")
end
