ERROR: LoadError: Dependency variable ./ not found in context
Stacktrace:
 [1] error(s::String)
   @ Base ./error.jl:35
 [2] apply_dependency(d::Main.SED.FunctionalDependency, signal::Vector{Float64}, context::@NamedTuple{N::Int64, q::Main.SED.SEDist{Main.SED.RandomSource{Uniform{Float64}}, Main.SED.NoDependency}, w::Main.SED.SEDist{Main.SED.RandomSource{Uniform{Float64}}, Main.SED.NoDependency}, K::Float64, w̃::Main.SED.SEDist{Main.SED.RandomSource{Uniform{Float64}}, Main.SED.FunctionalDependency}, ū::Main.SED.SEDist{Main.SED.ZeroSource, Main.SED.FunctionalDependency}})
   @ Main.SED ~/SED/src/core.jl:353
 [3] sample!(d::Main.SED.SEDist{Main.SED.RandomSource{Uniform{Float64}}, Main.SED.FunctionalDependency}, N::Int64; context::@NamedTuple{N::Int64, q::Main.SED.SEDist{Main.SED.RandomSource{Uniform{Float64}}, Main.SED.NoDependency}, w::Main.SED.SEDist{Main.SED.RandomSource{Uniform{Float64}}, Main.SED.NoDependency}, K::Float64, w̃::Main.SED.SEDist{Main.SED.RandomSource{Uniform{Float64}}, Main.SED.FunctionalDependency}, ū::Main.SED.SEDist{Main.SED.ZeroSource, Main.SED.FunctionalDependency}}, random::Nothing)
   @ Main.SED ~/SED/src/core.jl:374
 [4] sample!(context::@NamedTuple{N::Int64, q::Main.SED.SEDist{Main.SED.RandomSource{Uniform{Float64}}, Main.SED.NoDependency}, w::Main.SED.SEDist{Main.SED.RandomSource{Uniform{Float64}}, Main.SED.NoDependency}, K::Float64, w̃::Main.SED.SEDist{Main.SED.RandomSource{Uniform{Float64}}, Main.SED.FunctionalDependency}, ū::Main.SED.SEDist{Main.SED.ZeroSource, Main.SED.FunctionalDependency}}, N::Int64; random::Nothing)
   @ Main.SED ~/SED/src/core.jl:411
 [5] sample!
   @ ~/SED/src/core.jl:395 [inlined]
 [6] #sample!#11
   @ ~/SED/src/core.jl:426 [inlined]
 [7] sample!(context::@NamedTuple{N::Int64, q::Main.SED.SEDist{Main.SED.RandomSource{Uniform{Float64}}, Main.SED.NoDependency}, w::Main.SED.SEDist{Main.SED.RandomSource{Uniform{Float64}}, Main.SED.NoDependency}, K::Float64, w̃::Main.SED.SEDist{Main.SED.RandomSource{Uniform{Float64}}, Main.SED.FunctionalDependency}, ū::Main.SED.SEDist{Main.SED.ZeroSource, Main.SED.FunctionalDependency}})
   @ Main.SED ~/SED/src/core.jl:418
 [8] top-level scope
   @ ~/SED/examples/readme_figures.jl:45
in expression starting at /Users/jonnorberg/SED/examples/readme_figures.jl:45
