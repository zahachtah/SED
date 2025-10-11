using Statistics, Distributions, Random, LinearAlgebra
import Base: show
using Base: @kwdef

import Statistics: mean, median, std, var
Constant = Dirac

struct Derived <: ContinuousUnivariateDistribution
    data::Vector{Float64}
end
struct Data <: ContinuousUnivariateDistribution
    data::Vector{Float64}
end
mean(d::Union{Derived,Data}) = Statistics.mean(d.data)
median(d::Union{Derived,Data}) = Statistics.median(d.data)
std(d::Union{Derived,Data}) = Statistics.std(d.data)
var(d::Union{Derived,Data}) = Statistics.var(d.data)

@kwdef mutable struct Dist{T,N,A<:AbstractArray{T,N}} <: AbstractArray{T,N}
    data::A = nothing
    min::Union{Nothing,Float64} = nothing
    max::Union{Nothing,Float64} = nothing
    mean::Union{Nothing,Float64} = nothing
    median::Union{Nothing,Float64} = nothing
    sigma::Union{Nothing,Float64} = nothing
    sum::Union{Nothing,Float64} = nothing
    alpha::Union{Nothing,Float64} = nothing
    beta::Union{Nothing,Float64} = nothing
    random::Bool = false
    normalize::Bool = false
    dependent::NamedTuple = NamedTuple()
    distribution::Any = Uniform
    dependency_function::Union{Function,AbstractString,Nothing} = (indep, dep) -> indep .+ dep
    bounds_quantiles::Tuple{Float64,Float64} = (0.01, 0.99)
    determ_bounds::Symbol = :within
    random_bounds::Symbol = :none
    enforce_after_deps::Symbol = :none
end

change(params::NamedTuple; kwargs...) = (; params..., kwargs...)

function _infer_dep_keys(expr_str::AbstractString, context::NamedTuple)
    ex = Meta.parse(expr_str)
    syms = Set{Symbol}()
    function walk(e)
        if e isa Symbol
            push!(syms, e)
        elseif e isa Expr
            for a in e.args
                walk(a)
            end
        end
    end
    walk(ex)
    delete!(syms, :sed); delete!(syms, :independent)
    return [s for s in syms if haskey(context, s)]
end

function _unknown_idents(expr_str::AbstractString, context::NamedTuple)
    ex = Meta.parse(expr_str)
    syms = Set{Symbol}()
    function walk(e)
        if e isa Symbol
            push!(syms, e)
        elseif e isa Expr
            for a in e.args
                walk(a)
            end
        end
    end
    walk(ex)
    delete!(syms, :sed); delete!(syms, :independent)
    allowed_funcs = Set([:min, :max, :clamp, :abs, :sqrt, :exp, :log])
    syms = setdiff(syms, allowed_funcs)
    unknown = Symbol[]
    for s in syms
        if Base.isidentifier(String(s)) && !haskey(context, s)
            push!(unknown, s)
        end
    end
    return unknown
end

function apply_dependencies!(sed::Dist, N::Int, context::NamedTuple)
    if isempty(sed.dependent) && (sed.dependency_function === nothing)
        return sed
    end
    keys_list = [k for k in keys(sed.dependent) if k != :fun]
    depvals = Dict{Symbol,Any}()
    for k in keys_list
        haskey(context, k) || error("Context does not contain dependency variable $(k)")
        v = context[k]
        depvals[k] = hasproperty(v, :data) ? v.data : v
    end
    if haskey(sed.dependent, :fun)
        fun = sed.dependent.fun
        scaled = Dict{Symbol,Any}()
        for k in keys_list
            factor = sed.dependent[k]
            dv = depvals[k]
            scaled[k] = factor isa Function ? factor(dv) : (factor isa Number ? factor .* dv : dv)
        end
        dep_contrib = fun(NamedTuple{Tuple(keys(scaled))}(values(scaled)))
        sed.data = sed.dependency_function(sed.data, dep_contrib)
        if sed.enforce_after_deps != :none && sed.min !== nothing && sed.max !== nothing && sed.max > sed.min
            sed.data = clamp.(sed.data, sed.min, sed.max)
        end
        return sed
    end
    if sed.dependency_function !== nothing
        df = sed.dependency_function
        indep = sed.data
        if df isa Function
            if isempty(depvals)
                return sed
            end
            deps_nt = NamedTuple{Tuple(keys(depvals))}(values(depvals))
            try
                sed.data = df(indep, deps_nt)
            catch
                sed.data = df(deps_nt)
            end
            if sed.enforce_after_deps != :none && sed.min !== nothing && sed.max !== nothing && sed.max > sed.min
                sed.data = clamp.(sed.data, sed.min, sed.max)
            end
            return sed
        else
            unknown = _unknown_idents(String(df), context)
            isempty(unknown) || error("Unknown identifiers in dependency_fun: $(unknown)")
            deps_keys = isempty(keys_list) ? _infer_dep_keys(String(df), context) : keys_list
            deps_nt = NamedTuple{Tuple(deps_keys)}(map(k -> depvals[k], deps_keys))
            independent = indep
            sed.data = let independent=independent, deps=deps_nt
                (; (Symbol(k)=>getfield(deps, k) for k in fieldnames(typeof(deps)))...)
                eval(Meta.parse(String(df)))
            end
            if sed.enforce_after_deps != :none && sed.min !== nothing && sed.max !== nothing && sed.max > sed.min
                sed.data = clamp.(sed.data, sed.min, sed.max)
            end
            return sed
        end
    end
    dep_sum = zeros(eltype(sed.data), N)
    for k in keys_list
        dv = depvals[k]
        dep_sum .+= dv
    end
    sed.data = sed.dependency_function(sed.data, dep_sum)
    sed
end

function is_distribution_type(sed, dist)
    return sed.distribution == dist || sed.distribution isa dist
end
has_dependencies(sed::Dist) = !isempty(sed.dependent)

function is_property_name(s::Symbol, property_name::Symbol)
    return s == property_name || (s == :w && property_name == :w̃) || (s == :u && property_name == :ū)
end

function find_dist_by_name(context::NamedTuple, name::Symbol)
    for (k, v) in pairs(context)
        if v isa Dist && is_property_name(name, k)
            return v
        end
    end
    return nothing
end

function generate_distribution!(sed::Dist, N::Int)
    rev = false
    if sed.min === nothing && sed.max === nothing && sed.mean === nothing &&
       sed.median === nothing && sed.sigma === nothing && sed.sum === nothing &&
       sed.alpha === nothing && sed.beta === nothing &&
       ((!isempty(sed.dependent)) || (sed.dependency_function isa AbstractString))
        sed.data = zeros(eltype(sed.data), N)
        return sed
    end
    if is_distribution_type(sed, LogNormal)
        if sed.min !== nothing && sed.max !== nothing && sed.max != sed.min
            xlo = min(sed.min, sed.max)
            xhi = max(sed.min, sed.max)
            xlo = xlo <= 0 ? 1e-6 : xlo
            qlo, qhi = sed.bounds_quantiles
            z1 = quantile(Normal(), qlo)
            z2 = quantile(Normal(), qhi)
            σ = (log(xhi) - log(xlo)) / (z2 - z1)
            μ = log(xlo) - σ * z1
            sed.distribution = LogNormal(μ, abs(σ))
        elseif sed.mean !== nothing && sed.sigma !== nothing
            sed.distribution = (sed.sigma != 0.0) ? LogNormal(log(sed.mean) - abs(sed.sigma)^2 / 2, abs(sed.sigma)) : Constant(sed.mean)
        elseif sed.median !== nothing && sed.sigma !== nothing
            sed.distribution = (sed.sigma != 0.0) ? LogNormal(log(sed.median), abs(sed.sigma)) : Constant(sed.median)
        end
        if sed.random
            if sed.random_bounds == :none || sed.min === nothing || sed.max === nothing || sed.min >= sed.max
                sed.data = rand(sed.distribution, N)
            else
                lo, hi = sed.min, sed.max
                data = similar(zeros(N))
                i = 1
                while i <= N
                    x = rand(sed.distribution)
                    if lo <= x <= hi
                        data[i] = x
                        i += 1
                    end
                end
                sed.data = data
            end
        else
            if sed.min !== nothing && sed.max !== nothing && sed.max != sed.min && sed.determ_bounds == :within
                qlo, qhi = sed.bounds_quantiles
                probs = (N == 1) ? [0.5] : collect(range(qlo, qhi, length=N))
                sed.data = quantile.(Ref(sed.distribution), probs)
            elseif sed.determ_bounds == :clip && sed.min !== nothing && sed.max !== nothing && sed.max != sed.min
                probs = collect(range(1 / N, stop=1 - 1 / N, length=N))
                qlo, qhi = sed.bounds_quantiles
                probs = clamp.(probs, qlo, qhi)
                sed.data = quantile.(Ref(sed.distribution), probs)
            else
                probs = collect(range(1 / N, stop=1 - 1 / N, length=N))
                sed.data = quantile.(Ref(sed.distribution), probs)
            end
        end
    elseif is_distribution_type(sed, Uniform)
        if sed.min !== nothing && sed.max !== nothing
            rev = sed.min > sed.max
            if sed.max != sed.min
                sed.distribution = Uniform(minimum((sed.min, sed.max)), maximum((sed.min, sed.max)))
            else
                sed.distribution = Constant(sed.min)
            end
        elseif sed.mean !== nothing && sed.sigma !== nothing
            rev = sed.sigma < 0
            sed.distribution = (sed.sigma != 0.0) ? Uniform(sed.mean - abs(sed.sigma) / 2, sed.mean + abs(sed.sigma) / 2) : Constant(sed.mean)
        elseif sed.median !== nothing && sed.sigma !== nothing
            rev = sed.sigma < 0
            sed.distribution = (sed.sigma != 0.0) ? Uniform(sed.median - abs(sed.sigma) / 2, sed.median + abs(sed.sigma) / 2) : Constant(sed.median)
        end
        if sed.random
            sed.data = rand(sed.distribution, N)
        else
            qs = quantile.(Ref(sed.distribution), range(1 / N, stop=1 - 1 / N, length=N))
            sed.data = (N == 1) ? [quantile(sed.distribution, 0.5)] : (rev ? reverse(qs) : qs)
        end
    elseif is_distribution_type(sed, Beta)
        if sed.alpha !== nothing && sed.beta !== nothing
            (sed.alpha <= 0 || sed.beta <= 0) && error("For Beta, alpha and beta must be > 0")
            sed.distribution = Beta(sed.alpha, sed.beta)
        elseif sed.mean !== nothing && sed.sigma !== nothing
            m = sed.mean; s = abs(sed.sigma)
            if s == 0.0
                sed.distribution = Dirac(m)
            else
                (m <= 0 || m >= 1) && error("For Beta mean+sigma, mean must be in (0,1)")
                v = s^2; vmax = m * (1 - m)
                (v <= 0 || v >= vmax) && error("For Beta mean+sigma, sigma too large for mean (requires sigma^2 < mean*(1-mean))")
                κ = m * (1 - m) / v - 1
                α = m * κ; β = (1 - m) * κ
                sed.alpha = α; sed.beta = β
                sed.distribution = Beta(α, β)
            end
        else
            error("For Beta, specify alpha & beta, or mean & sigma")
        end
        sed.data = sed.random ? rand(sed.distribution, N) : quantile.(Ref(sed.distribution), range(1 / N, stop=1 - 1 / N, length=N))
    elseif is_distribution_type(sed, Normal)
        if sed.distribution isa Normal
            nothing
        elseif sed.mean !== nothing && sed.sigma !== nothing
            s = abs(sed.sigma); sed.distribution = (s == 0.0) ? Dirac(sed.mean) : Normal(sed.mean, s)
        elseif sed.median !== nothing && sed.sigma !== nothing
            s = abs(sed.sigma); sed.distribution = (s == 0.0) ? Dirac(sed.median) : Normal(sed.median, s)
        else
            error("For Normal, specify mean & sigma (or median & sigma), or pass a Normal instance")
        end
        sed.data = sed.random ? rand(sed.distribution, N) : quantile.(Ref(sed.distribution), range(1 / N, stop=1 - 1 / N, length=N))
    elseif is_distribution_type(sed, LogitNormal)
        if sed.median !== nothing && sed.sigma !== nothing
            m = sed.median; s = abs(sed.sigma)
            (m <= 0 || m >= 1) && error("For LogitNormal median+sigma, median must be in (0,1)")
            sed.distribution = s == 0.0 ? Dirac(m) : LogitNormal(log(m / (1 - m)), s)
        elseif sed.distribution isa LogitNormal
            nothing
        else
            error("For LogitNormal, specify median & sigma, or pass a LogitNormal instance")
        end
        sed.data = sed.random ? rand(sed.distribution, N) : quantile.(Ref(sed.distribution), range(1 / N, stop=1 - 1 / N, length=N))
    elseif is_distribution_type(sed, Dirac)
        if sed.mean !== nothing
            sed.distribution = Dirac(sed.mean)
        elseif sed.median !== nothing
            sed.distribution = Dirac(sed.median)
        elseif sed.min !== nothing && sed.max !== nothing && sed.min == sed.max
            sed.distribution = Dirac(sed.min)
        else
            error("For Dirac, specify a value in mean or median (or min==max)")
        end
        sed.data = rand(sed.distribution, N)
    elseif is_distribution_type(sed, Bernoulli)
        p = sed.mean !== nothing ? sed.mean : error("For Bernoulli, please specify the probability in sed.mean")
        sed.distribution = Bernoulli(p)
        sed.data = sed.random ? rand(sed.distribution, N) : quantile.(Ref(sed.distribution), range(1 / N, stop=1 - 1 / N, length=N))
    else
        error("Unsupported distribution type: $(sed.distribution)")
    end
    if sed.normalize
        sed.data .= sed.data ./ N
    end
    sed
end

function sample!(sed::Dist, N::Int; context=nothing, random::Union{Nothing,Bool}=nothing)
    old_random = sed.random
    if random !== nothing
        sed.random = random
    end
    try
        generate_distribution!(sed, N)
        if context !== nothing
            apply_dependencies!(sed, N, context)
        end
    finally
        sed.random = old_random
    end
    sed
end

function sample!(s, param_name::Symbol; N::Union{Nothing,Int}=nothing, random::Union{Nothing,Bool}=nothing)
    N === nothing && (N = s.N)
    sed = find_dist_by_name(s, param_name)
    sed === nothing && error("Could not find SED parameter named $(param_name) in the scenario")
    return sample!(sed, N; context=s, random)
end

function dependency_graph(s)
    is_sed_val(v) = (v isa Dist) || (hasfield(typeof(v), :dependent) && hasfield(typeof(v), :dependency_function))
    sedkeys = Symbol[]
    for (k, v) in pairs(s)
        is_sed_val(v) && push!(sedkeys, k)
    end
    deps = Dict{Symbol,Vector{Symbol}}(k => Symbol[] for k in sedkeys)
    for k in sedkeys
        v = getfield(s, k)
        if is_sed_val(v) && has_dependencies(v)
            for dk in keys(v.dependent)
                dk == :fun && continue
                dk in sedkeys && push!(deps[k], dk)
            end
        elseif is_sed_val(v) && (v.dependency_function isa AbstractString)
            for dk in _infer_dep_keys(v.dependency_function, s)
                dk in sedkeys && push!(deps[k], dk)
            end
        end
    end
    indeg = Dict(k => 0 for k in sedkeys)
    for k in sedkeys; for d in deps[k]; indeg[k] += 1; end; end
    ready = [k for k in sedkeys if indeg[k] == 0]
    order = Symbol[]
    while !isempty(ready)
        n = popfirst!(ready)
        push!(order, n)
        for m in sedkeys
            if n in deps[m]
                indeg[m] -= 1
                indeg[m] == 0 && push!(ready, m)
            end
        end
    end
    length(order) == length(sedkeys) || error(ArgumentError("Cyclic SED dependencies detected among: $(setdiff(sedkeys, order))"))
    return (; nodes=sedkeys, edges=deps, order)
end

function sample!(s; N::Union{Nothing,Int}=nothing, random::Union{Nothing,Bool}=nothing)
    N === nothing && (N = s.N)
    g = dependency_graph(s)
    for k in g.order
        v = getfield(s, k)
        needs_deps = has_dependencies(v) || (v.dependency_function isa AbstractString) || ((v.dependency_function isa Function) && !isempty(v.dependent))
        if needs_deps
            sample!(v, N; context=s, random)
        else
            sample!(v, N; random)
        end
    end
    return s
end

function sample!(context::NamedTuple, N::Int; random::Union{Nothing,Bool}=nothing)
    new_context = map(x -> (x isa Dist ? sample!(x, N; context=context, random) : x), context)
    return new_context
end

function sample!(context::NamedTuple; N::Union{Nothing,Int}=nothing, random::Union{Nothing,Bool}=nothing)
    if N === nothing
        haskey(context, :N) || error("Provide N=... or include :N in the context NamedTuple")
        N = context.N
    end
    return sample!(context, N; random)
end

Base.size(sed::Dist) = size(sed.data)
Base.getindex(sed::Dist, idx...) = getindex(sed.data, idx...)
Base.setindex!(sed::Dist, value, idx...) = setindex!(sed.data, value, idx...)

function Base.similar(sed::Dist{T,N,A}, ::Type{T}, dims::Dims) where {T,N,A<:AbstractArray{T,N}}
    return Dist(
        data=similar(sed.data, T, dims),
        min=sed.min,
        max=sed.max,
        mean=sed.mean,
        median=sed.median,
        sigma=sed.sigma,
        sum=sed.sum,
        alpha=sed.alpha,
        beta=sed.beta,
        random=sed.random,
        normalize=sed.normalize,
        dependent=sed.dependent,
        distribution=sed.distribution,
        dependency_function=sed.dependency_function
    )
end

Base.iterate(sed::Dist, state...) = iterate(sed.data, state...)

function dist(; data=nothing, min=nothing, max=nothing, kwargs...)
    kw = (; kwargs...)
    if haskey(kw, :dependency_fun) && !haskey(kw, :dependency_function)
        kw = change(kw; dependency_function=kw.dependency_fun)
        pairs = [(k => getproperty(kw, k)) for k in keys(kw) if k != :dependency_fun]
        kw = (; pairs...)
    end
    if haskey(kw, :dependent)
        depval = kw.dependent
        if depval isa Tuple
            syms = Tuple(depval)
            nt = NamedTuple{syms}(ntuple(_ -> 1.0, length(syms)))
            kw = change(kw; dependent=nt)
        elseif depval isa Vector{Symbol}
            syms = Tuple(depval)
            nt = NamedTuple{syms}(ntuple(_ -> 1.0, length(syms)))
            kw = change(kw; dependent=nt)
        end
    end
    allowed = Set([:min, :max, :mean, :median, :sigma, :sum, :alpha, :beta, :random, :normalize, :dependent, :distribution, :dependency_function,
        :bounds_quantiles, :determ_bounds, :random_bounds, :enforce_after_deps])
    filtered_pairs = [(k => getproperty(kw, k)) for k in keys(kw) if k in allowed]
    filtered_kw = (; filtered_pairs...)
    T = Float64; ND = 1; A = Array{T,ND}
    if data !== nothing
        T = eltype(data); ND = ndims(data); A = typeof(data)
    else
        data = Array{T,ND}(undef, 0)
    end
    return Dist{T,ND,A}(; data, min, max, filtered_kw...)
end

function astext(d::Dist)
    b = IOBuffer(); show(b, MIME"text/plain"(), d); String(take!(b))
end

function Base.show(io::IO, d::Dist)
    distname = d.distribution isa Type ? string(d.distribution) :
               try nameof(typeof(d.distribution)) catch; string(typeof(d.distribution)) end
    ndata = (d.data isa AbstractArray) ? length(d.data) : 0
    print(io, "Dist($distname, length=$ndata)")
end

function Base.show(io::IO, ::MIME"text/plain", d::Dist)
    distname = d.distribution isa Type ? string(d.distribution) :
               try nameof(typeof(d.distribution)) catch; string(typeof(d.distribution)) end
    println(io, "Dist(")
    println(io, "  distribution : ", distname)
    println(io, "  params       : ", "min=", d.min, ", max=", d.max, ", mean=", d.mean,
        ", median=", d.median, ", sigma=", d.sigma, ", sum=", d.sum, ", alpha=", d.alpha, ", beta=", d.beta)
    println(io, "  options      : ", "random=", d.random, ", normalize=", d.normalize)
    if !isempty(d.dependent)
        println(io, "  dependent    : ", join(Symbol.(keys(d.dependent)), ", "))
    else
        println(io, "  dependent    : ∅")
    end
    depf = d.dependency_function
    if depf === nothing
        println(io, "  dep_fun      : ∅")
    elseif depf isa AbstractString
        println(io, "  dep_fun      : \"", depf, "\"")
    else
        println(io, "  dep_fun      : Function")
    end
    if d.data isa AbstractArray && !isempty(d.data)
        dmin = try minimum(d.data) catch; "?" end
        dmax = try maximum(d.data) catch; "?" end
        println(io, "  data         : length=", length(d.data), ", eltype=", eltype(d.data), ", min=", dmin, ", max=", dmax)
    else
        println(io, "  data         : ∅ (not sampled)")
    end
    print(io, ")")
end

function getmedian(d::Dist; sampled::Bool=false)
    if sampled && d.data !== nothing && !isempty(d.data)
        return median(d.data)
    end
    try
        return quantile(d.distribution, 0.5)
    catch end
    if d.distribution === LogNormal && d.min !== nothing && d.max !== nothing && d.max != d.min
        xlo = min(d.min, d.max); xhi = max(d.min, d.max); xlo = xlo <= 0 ? 1e-6 : xlo
        qlo, qhi = d.bounds_quantiles
        z1 = quantile(Normal(), qlo); z2 = quantile(Normal(), qhi)
        σ = (log(xhi) - log(xlo)) / (z2 - z1)
        μ = log(xlo) - σ * z1
        return exp(μ)
    end
    if d.median !== nothing
        return d.median
    elseif d.min !== nothing && d.max !== nothing
        return (d.min + d.max) / 2
    elseif d.mean !== nothing
        return d.mean
    else
        return NaN
    end
end

function getsigma(d::Dist; sampled::Bool=false)
    if sampled && d.data !== nothing && !isempty(d.data)
        return std(d.data)
    end
    try
        if d.distribution isa LogNormal
            return (d.distribution::LogNormal).σ
        elseif d.distribution isa Normal
            return (d.distribution::Normal).σ
        end
    catch end
    if d.distribution === LogNormal && d.min !== nothing && d.max !== nothing && d.max != d.min
        xlo = min(d.min, d.max); xhi = max(d.min, d.max); xlo = xlo <= 0 ? 1e-6 : xlo
        qlo, qhi = d.bounds_quantiles
        z1 = quantile(Normal(), qlo); z2 = quantile(Normal(), qhi)
        return (log(xhi) - log(xlo)) / (z2 - z1)
    end
    return d.sigma === nothing ? missing : d.sigma
end

