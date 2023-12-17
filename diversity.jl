using Statistics
using Base: @kwdef
import Base: show

@kwdef mutable struct SED{T, N, A<:AbstractArray{T,N}} <: AbstractArray{T,N}
    data::A = nothing
    min::Union{Nothing, Float64} = nothing
    max::Union{Nothing, Float64} = nothing
    mean::Union{Nothing, Float64} = nothing
    median::Union{Nothing, Float64} = nothing
    spread::Union{Nothing, Float64} = nothing
    sum::Union{Nothing, Float64} = nothing
    rand::Bool = false
    normalize::Bool = false
    dependent::NamedTuple = NamedTuple()
    distribution::Any = :linear
end

function show(io::IO, sed::SED{T, N, A}) where {T, N, A<:AbstractArray{T,N}}
    isnothing(sed.min) ? nothing : print(io, "Min:",sed.min," ")
    isnothing(sed.max) ? nothing : print(io, "Max:",sed.max," ")
    isnothing(sed.mean) ? nothing : print(io, "Mean:",sed.mean," ")
    isnothing(sed.median) ? nothing : print(io, "Median:",sed.median," ")
    isnothing(sed.spread) ? nothing : print(io, "Spread:",sed.spread," ")
    isnothing(sed.sum) ? nothing : print(io, "Sum:",sed.sum," ")
    isnothing(sed.distribution) ? nothing  : print(io, "Distribution: ",sed.rand ? "random " : "",sed.distribution)
end

function dist(s::SED,N::Int64)
    dist!(s,N)
    return s
end

# in case you define a variable that is not a SED type
function dist!(s,N::Int64)
    return s
end

function dist!(s::SED, N::Int64)
    if s.min !== nothing && s.max !== nothing && s.rand==false
        s.data= N==1 ? [(s.max+s.min)/2] : collect(range(s.min, stop=s.max, length=N))
	elseif s.min !== nothing && s.max !== nothing && s.rand==true
        s.data = s.min.+(s.max-s.min).*rand(N)
    elseif s.mean !== nothing && s.spread !== nothing && s.rand==false && s.distribution==:linear
        s.data= N==1 ? [s.mean] : collect(range(s.mean-s.spread/2, stop=s.mean+s.spread/2, length=N))
    elseif s.mean !== nothing && s.spread !== nothing && s.rand==true && s.distribution==:linear
        s.data = s.mean.-s.spread/2 .+ s.spread*rand(N)
    elseif s.mean !== nothing && s.spread !== nothing && s.rand==true && s.distribution==:lognormal
        s.data= N==1 ? [s.mean] : rand(LogNormal(log(s.mean),s.spread),N)
    end
    s.normalize ? s.data=s.data./N : nothing
    return s
end# Define a default constructor for when no arguments are given


function SED(; data=nothing, min=nothing, max=nothing, kwargs...)
    T = Float64  # Default type if not inferred from `data`
    N = 1        # Default number of dimensions
    A = Array{T, N} # Default array type if not inferred from `data`

    # Infer the type and dimensions from provided data
    if data !== nothing
        T, N = eltype(data), ndims(data)
        A = typeof(data)
    else

        data = A(undef, 0) # Or however you want to handle the case where there is no data

    end
    
    sed = SED{T, N, A}(;data, min, max, kwargs...)
    return sed
end

Base.size(a::SED) = size(a.data)
Base.getindex(a::SED, i...) = getindex(a.data, i...)
Base.setindex!(a::SED, v, i...) = setindex!(a.data, v, i...)
function Base.similar(a::SED{T, N, A}, ::Type{T}, dims::Dims) where {T, N, A<:AbstractArray{T,N}}
    return SED(
        data = similar(a.data, T, dims),
        min = a.min,
        max = a.max,
        mean = a.mean,
        median = a.median,
        spread = a.spread,
        sum = a.sum,
        rand = a.rand,
        normalize = a.normalize,
        dependent = a.dependent,
        distribution = a.distribution
    )
end
Base.iterate(a::SED, state...) = iterate(a.data, state...)
#=
function Base.show(io::IO, sed::SED{T, N, A}) where {T, N, A<:AbstractArray{T,N}}
    print(io, "SED with properties:\n")
    println(io, "Min: ", isnothing(sed.min) ? "Not calculated" : sed.min)
    println(io, "Max: ", isnothing(sed.max) ? "Not calculated" : sed.max)
    println(io, "Mean: ", isnothing(sed.mean) ? "Not calculated" : sed.mean)
    println(io, "Median: ", isnothing(sed.median) ? "Not calculated" : sed.median)
    println(io, "Sum: ", isnothing(sed.sum) ? "Not calculated" : sed.sum)
    println(io, "rand: ", sed.rand)
    println(io, "Distribution: ", isnothing(sed.distribution) ? "Not calculated" : sed.distribution)
    # Optionally print the array data itself
    # println(io, "Data: ", sed.data)
end=#