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
    distribution::Any = Uniform
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

function distold!(s::SED, N::Int64)
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

function dist!(s::SED, N::Int64)
    println(s)
    if s.min !== nothing && s.max !== nothing && s.max!=s.min
        if s.distribution==LogNormal
        # Nonlinear problem to find μ and σ of the lognormal distribution given min and max of 1/N and 1-1/N quantiles (is there an analytical?)    
        f(u,p)=quantile.(LogNormal(u[1],abs(u[2])),[1/p[3],1-1/p[3]]).-[p[1],p[2]]
        sol = solve(NonlinearProblem(f, [0.1,0.5], [s.min,s.max,N]))
        s.distribution=LogNormal(sol.u[1],sol.u[2])
        elseif s.distribution==Uniform
            s.distribution=Uniform(s.min,s.max)
        end
    elseif s.mean!== nothing && s.spread!==nothing && s.spread!=0.0
        if s.distribution==LogNormal
            s.distribution=LogNormal(log(s.mean)-s.spread^2/2,s.spread)
        elseif s.distribution==Uniform
            s.distribution=Uniform(s.mean-s.spread/2,s.mean+s.spread/2)
        end
    elseif s.median!== nothing && s.spread!==nothing && s.spread!=0.0
        if s.distribution==LogNormal
            s.distribution=LogNormal(log(s.median),s.spread)
        elseif s.distribution==Uniform
            s.distribution=Uniform(s.mean-abs(s.spread)/2,s.mean+abs(s.spread)/2)
        end
        # move this to the end and leave the "intended" distribution as is
    elseif s.min==s.max
        s.distribution=Dirac(s.min) 
    elseif s.mean!=nothing && s.spread==0.0
        s.distribution=Dirac(s.mean) 
    elseif s.median!=nothing && s.spread==0.0
        s.distribution=Dirac(s.median) 
    end

    if s.rand==true
        s.data=rand(s.distribution,N)
    else
        s.data=quantile.(s.distribution,(s.spread !== nothing && s.spread<0) ? reverse(range(1/N, stop=1-1/N, length=N)) : range(1/N, stop=1-1/N, length=N))
    end
    

    s.normalize ? s.data=s.data./N : nothing
    return s
end


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
