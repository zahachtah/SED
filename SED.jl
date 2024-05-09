using Colors, Statistics, OrdinaryDiffEq, Distributions,CairoMakie, FileIO, Graphs, Random, KernelDensity, ColorSchemes, NetworkLayout
using DiffEqCallbacks: TerminateSteadyState
using Base: @kwdef
import Base: show
import Distributions: pdf



include("diversity.jl")
include("scenario.jl")
include("model.jl")
include("abstract_institutions.jl")
include("specified_institutions.jl")
include("utils.jl")
include("visualizations.jl")
include("figure_codes/figures.jl")

set_theme!(theme_light())