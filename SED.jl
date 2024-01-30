using Colors, Statistics, OrdinaryDiffEq, Distributions,CairoMakie, FileIO, Graphs, Random, KernelDensity, ColorSchemes, NetworkLayout
using DiffEqCallbacks: TerminateSteadyState
using Base: @kwdef
import Base: show
import Distributions: pdf



include("diversity.jl")
include("scenario.jl")
include("model.jl")
include("institutions.jl")
include("utils.jl")
include("visualizations.jl")
include("figures.jl")

set_theme!(theme_light())