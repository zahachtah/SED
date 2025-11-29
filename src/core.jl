using Statistics, Distributions, Random, LinearAlgebra
import Base: show, getindex, setindex!, size, similar, iterate
using Base: @kwdef

import Statistics: mean, median, std, var

# --- Abstract Types ---
abstract type AbstractSource end
abstract type AbstractDependency end

# --- Sources ---

# 1. Random Source (Parametric Distribution)
struct RandomSource{D<:Distribution} <: AbstractSource
    dist::D
    random::Bool # Default randomness preference
end

# 2. Data Source (Fixed Data)
struct DataSource <: AbstractSource
    data::Vector{Float64}
end

# 3. Zero Source (For pure dependencies)
struct ZeroSource <: AbstractSource end

# --- Dependencies ---

# 1. No Dependency (Identity)
struct NoDependency <: AbstractDependency end

# 2. Functional Dependency
struct FunctionalDependency <: AbstractDependency
    fn::Function          # (independent, inputs...) -> output
    inputs::Vector{Symbol} # Names of inputs
    expr_str::String      # For display/debugging
end

# --- Main Struct ---

mutable struct SEDist{S<:AbstractSource,D<:AbstractDependency} <: AbstractArray{Float64,1}
    source::S
    dependency::D

    # Post-processing options
    min::Union{Float64,Nothing}
    max::Union{Float64,Nothing}
    normalize::Bool

    # Cache
    data::Vector{Float64}

    # Metadata
    unit::Union{String,Nothing}
end

change(params::NamedTuple; kwargs...) = (; params..., kwargs...)

# --- Property Access ---

function Base.getproperty(d::SEDist, sym::Symbol)
    if hasfield(SEDist, sym)
        return getfield(d, sym)
    elseif sym === :mean
        return mean(d)
    elseif sym === :sigma || sym === :std
        return std(d)
    else
        # Forward to source? Or error?
        # Let's error for now to avoid confusion, unless we want to forward everything.
        error("type SEDist has no field $sym")
    end
end

# --- Statistics Forwarding ---

mean(s::RandomSource) = mean(s.dist)
std(s::RandomSource) = std(s.dist)
mean(s::DataSource) = mean(s.data)
std(s::DataSource) = std(s.data)
mean(s::ZeroSource) = 0.0
std(s::ZeroSource) = 0.0

mean(d::SEDist) = mean(d.source)
std(d::SEDist) = std(d.source)

# --- Display ---

function Base.show(io::IO, s::RandomSource)
    print(io, "RandomSource(", s.dist, ")")
end

function Base.show(io::IO, s::DataSource)
    print(io, "DataSource(n=", length(s.data), ")")
end

function Base.show(io::IO, s::ZeroSource)
    print(io, "ZeroSource")
end

function Base.show(io::IO, d::NoDependency)
    print(io, "NoDependency")
end

function Base.show(io::IO, d::FunctionalDependency)
    print(io, "FunctionalDependency(", d.expr_str, ")")
end

function Base.show(io::IO, d::SEDist)
    print(io, "SEDist(", d.source, ", ", d.dependency, ")")
end

function Base.show(io::IO, ::MIME"text/plain", d::SEDist)
    println(io, "SEDist:")
    println(io, "  Source: ", d.source)
    println(io, "  Dependency: ", d.dependency)
    if !isempty(d.data)
        println(io, "  Data: ", length(d.data), " elements")
        # print(io, "    ", d.data) # Optional: show data preview
    else
        println(io, "  Data: (empty)")
    end
end

# --- Constructors / Factory ---

# Helper to build specific distributions
function build_distribution(::Type{Uniform}, kw)
    if haskey(kw, :min) && haskey(kw, :max)
        mn, mx = kw[:min], kw[:max]
        if mn == mx
            return Dirac(mn)
        end
        return Uniform(min(mn, mx), max(mn, mx))
    elseif haskey(kw, :mean) && haskey(kw, :sigma)
        w = abs(kw[:sigma]) / 2
        return Uniform(kw[:mean] - w, kw[:mean] + w)
    elseif haskey(kw, :median) && haskey(kw, :sigma)
        w = abs(kw[:sigma]) / 2
        return Uniform(kw[:median] - w, kw[:median] + w)
    end
    return Uniform(0, 1)
end

function build_distribution(::Type{Normal}, kw)
    μ = get(kw, :mean, get(kw, :median, 0.0))
    σ = get(kw, :sigma, 1.0)
    return Normal(μ, abs(σ))
end

function build_distribution(::Type{LogNormal}, kw)
    if haskey(kw, :min) && haskey(kw, :max)
        # Quantile matching
        q_lo = get(kw, :bounds_quantiles, (0.01, 0.99))[1]
        q_hi = get(kw, :bounds_quantiles, (0.01, 0.99))[2]

        x_lo, x_hi = kw[:min], kw[:max]
        if x_lo <= 0 || x_hi <= 0
            # Fallback or error? For now, safe fallback to avoid crash if user gives bad inputs
            x_lo = max(x_lo, 1e-6)
            x_hi = max(x_hi, 1e-6)
        end

        z_lo = quantile(Normal(), q_lo)
        z_hi = quantile(Normal(), q_hi)

        if x_lo == x_hi
            return LogNormal(log(x_lo), 0.0)
        end

        σ = (log(x_hi) - log(x_lo)) / (z_hi - z_lo)
        μ = log(x_lo) - σ * z_lo
        return LogNormal(μ, abs(σ))

    elseif haskey(kw, :mean) && haskey(kw, :sigma)
        # Method of moments (approx)
        m, s = kw[:mean], kw[:sigma]
        if m <= 0
            return LogNormal(0, 1) # Invalid mean for LogNormal
        end
        σ_log = sqrt(log(1 + (s / m)^2))
        μ_log = log(m) - σ_log^2 / 2
        return LogNormal(μ_log, σ_log)
    elseif haskey(kw, :median) && haskey(kw, :sigma)
        # Median is exp(mu)
        m = kw[:median]
        if m <= 0
            return LogNormal(0, 1)
        end
        # Sigma is usually linear sigma? Or log sigma? 
        # Assuming linear sigma context similar to mean/sigma
        # But if sigma is passed with median, often it implies the shape parameter directly if no mean is present?
        # In the old code: 
        # elseif sed.median !== nothing && sed.sigma !== nothing
        #    μ = log(sed.median)
        #    σ = abs(sed.sigma)
        return LogNormal(log(m), abs(kw[:sigma]))
    end
    return LogNormal(0, 1)
end

function build_distribution(::Type{Bernoulli}, kw)
    p = get(kw, :mean, 0.5)
    return Bernoulli(p)
end

function build_distribution(::Type{Beta}, kw)
    if haskey(kw, :alpha) && haskey(kw, :beta)
        return Beta(kw[:alpha], kw[:beta])
    elseif haskey(kw, :mean) && haskey(kw, :sigma)
        m, s = kw[:mean], kw[:sigma]
        if s == 0
            # Degenerate Beta? Not supported by Distributions.jl directly as Beta
            # We could return a generic distribution or error. 
            # For now, let's approximate with very low variance or error.
            # But wait, Beta requires alpha, beta > 0.
            return Beta(1, 1) # Fallback
        end
        v = s^2
        if v >= m * (1 - m)
            error("Sigma too large for Beta mean")
        end
        κ = m * (1 - m) / v - 1
        α = m * κ
        β = (1 - m) * κ
        return Beta(α, β)
    end
    return Beta(1, 1)
end

# Fallback
build_distribution(T::Type{<:Distribution}, kw) = T()
build_distribution(d::Distribution, kw) = d


# Helper to parse dependency string
function parse_dependency(dep_str::String)
    # "q .* w .+ independent"
    # We need to identify variables.
    # This logic was in _infer_dep_keys

    ex = Meta.parse(dep_str)
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

    # Remove reserved words and math functions
    delete!(syms, :independent)
    delete!(syms, :sed) # Alias for independent

    math_funcs = Set([:+, :-, :*, :/, :^, :sqrt, :log, :exp, :abs, :min, :max, :clamp, :sin, :cos, :tan,
        :., :.+, :.-, :.*, :./, :.^])
    filter!(s -> !(s in math_funcs), syms)

    inputs = collect(syms)

    # Create function
    # (independent, inputs...) -> result

    # We need to construct a lambda that takes (independent, args...)
    # and evaluates the expression.
    # To make it robust, we use the same approach as before: eval a lambda generator.

    # Replace 'sed' with 'independent' in the expression string? 
    # Or just let the let-block handle it.

    expr = Meta.parse("@. " * dep_str)
    arg_syms = Symbol.(inputs)

    # Lambda: (independent, q, w) -> let sed=independent; @. ... end
    lambda_expr = Expr(:->, Expr(:tuple, :independent, arg_syms...),
        Expr(:block, Expr(:(=), :sed, :independent), expr))

    fn = Core.eval(@__MODULE__, lambda_expr)

    return FunctionalDependency(fn, inputs, dep_str)
end

"""
    @dependent (args...) -> body

Macro to define a dependency function.
Automatically handles `independent` (or `sed`) variable.
Example:
    @dependent (q, w) -> q .* w .+ independent
"""
macro dependent(expr)
    if expr.head != :-> && expr.head != :function
        error("@dependent expects a function definition (e.g., (x, y) -> x + y)")
    end

    # Extract arguments
    args = expr.args[1]
    body = expr.args[2]

    arg_syms = Symbol[]
    if args isa Symbol
        push!(arg_syms, args)
    elseif args isa Expr && args.head == :tuple
        for a in args.args
            if a isa Symbol
                push!(arg_syms, a)
            elseif a isa Expr && a.head == :(::)
                push!(arg_syms, a.args[1])
            else
                error("Unsupported argument type in @dependent")
            end
        end
    end

    # Check if independent is already an argument
    if :independent in arg_syms
        error("'independent' should not be an explicit argument in @dependent. It is injected automatically.")
    end

    # Construct new arguments: (independent, args...)
    new_args = Expr(:tuple, :independent, arg_syms...)

    # Construct new body: let sed = independent; body end
    new_body = Expr(:block, Expr(:(=), :sed, :independent), body)

    # Construct new function
    new_fn = Expr(:->, new_args, new_body)

    # Quote the result
    # We return a FunctionalDependency constructor call
    # We need to escape the function so it's defined in the caller's scope?
    # Actually, we want the function object.

    inputs_quoted = Expr(:vect, QuoteNode.(arg_syms)...)
    expr_str = string(expr)

    return quote
        FunctionalDependency($(esc(new_fn)), $inputs_quoted, $expr_str)
    end
end


function dist(;
    distribution=nothing,
    data=nothing,
    dependency_fun=nothing,
    dependency=nothing,
    random=false,
    normalize=false,
    unit=nothing,
    kwargs...
)
    kw = Dict{Symbol,Any}(kwargs)

    # 1. Build Source
    source = nothing
    if !isnothing(data)
        source = DataSource(data)
    elseif !isnothing(distribution)
        # Parametric
        DType = distribution isa Type ? distribution : typeof(distribution)
        d_obj = build_distribution(DType, kw)
        # If distribution instance passed, use it
        if !(distribution isa Type)
            d_obj = distribution
        end
        source = RandomSource(d_obj, random)
    elseif !isnothing(dependency_fun) || !isnothing(dependency)
        # Implicit source?
        # If dependency_fun uses 'independent', we need a source.

        uses_indep = false
        if !isnothing(dependency_fun)
            uses_indep = occursin("independent", dependency_fun) || occursin("sed", dependency_fun)
        end
        # For @dependent, we assume it might use independent (it's always passed).
        # But if we want to optimize, we could check the expression? 
        # Hard to check compiled function.
        # Let's assume YES for @dependent unless we want to force ZeroSource?
        # Actually, if no distribution is given, we default to Uniform(0,1) usually.
        # But if it's purely functional (e.g. q*w), we might want ZeroSource.
        # However, passing 0.0 as independent is fine for q*w.
        # Passing random noise is NOT fine if q*w doesn't use it? 
        # Actually it is fine, just unused.
        # BUT performance! Generating random numbers for nothing.

        # For now, let's stick to the logic: if no distribution, default to Uniform(0,1).
        # Unless we can prove independent is unused.

        # If dependency is provided, we don't know if it uses independent.
        # Let's default to Uniform(0,1) to be safe/consistent with legacy.

        if haskey(kw, :min) || haskey(kw, :max)
            d_obj = build_distribution(Uniform, kw)
            source = RandomSource(d_obj, random)
        else
            source = RandomSource(Uniform(0, 1), random)
        end
    else
        # Default default
        source = RandomSource(Uniform(0, 1), random)
    end

    # 2. Build Dependency
    dep_obj = nothing
    if !isnothing(dependency)
        dep_obj = dependency
    elseif !isnothing(dependency_fun)
        dep_obj = parse_dependency(dependency_fun)
    else
        dep_obj = NoDependency()
    end

    # 3. Options
    min_val = get(kw, :min, nothing)
    max_val = get(kw, :max, nothing)

    # Heuristic: If dependency is present AND distribution used min/max for construction,
    # assume min/max were for source parameterization, not result clamping.
    if !isnothing(dep_obj) && !(dep_obj isa NoDependency)
        if !isnothing(distribution)
            DType = distribution isa Type ? distribution : typeof(distribution)
            if DType <: LogNormal || DType <: Uniform
                min_val = nothing
                max_val = nothing
            end
        elseif haskey(kw, :min) || haskey(kw, :max)
            # Default was Uniform using min/max
            min_val = nothing
            max_val = nothing
        end
    end

    if !isnothing(min_val)
        min_val = Float64(min_val)
    end
    if !isnothing(max_val)
        max_val = Float64(max_val)
    end

    # 4. Create Struct
    return SEDist(source, dep_obj, min_val, max_val, normalize, Float64[], unit)
end


# --- Sampling Logic ---

# Generate Signal
function generate_signal(s::RandomSource, N::Int; random=nothing)
    use_random = isnothing(random) ? s.random : random
    if use_random
        return rand(s.dist, N)
    else
        # Quantiles
        # For N=1, return median
        if N == 1
            return [quantile(s.dist, 0.5)]
        end
        return quantile.(s.dist, range(1 / (N + 1), 1 - 1 / (N + 1), length=N))
        # Note: range(0,1) includes -Inf/Inf for some dists. 
        # Old code used: range(1/N, 1 - 1/N, length=N)
        # Let's match old code roughly
        # probs = collect(range(1 / N, stop=1 - 1 / N, length=N))
        # quantile.(Ref(sed.distribution), probs)
    end
end

function generate_signal(s::DataSource, N::Int; random=nothing)
    if length(s.data) != N
        # Resample or error? 
        # For now, just return data (assuming N matches or user handles it)
        # Or repeat/cycle?
        return s.data # Simplified
    end
    return s.data
end

function generate_signal(s::ZeroSource, N::Int; random=nothing)
    return zeros(Float64, N)
end


# Apply Dependency
function apply_dependency(d::NoDependency, signal, context)
    return signal
end

function apply_dependency(d::FunctionalDependency, signal, context)
    # Gather inputs
    # context is NamedTuple
    args = []
    for k in d.inputs
        if !haskey(context, k)
            error("Dependency variable $k not found in context")
        end
        val = context[k]
        # Unwrap if it's a SEDist
        push!(args, val isa AbstractArray ? val : val)
        # Note: if val is scalar, it broadcasts. If vector, it broadcasts.
    end

    # Call function
    # fn(independent, args...)
    # We use Base.invokelatest to be safe with eval'd functions
    return Base.invokelatest(d.fn, signal, args...)
end


# Main Sample
function sample!(d::SEDist, N::Int; context=nothing, random=nothing)
    # 1. Generate Independent Signal
    signal = generate_signal(d.source, N; random=random)

    # 2. Apply Dependency
    val = apply_dependency(d.dependency, signal, context)

    # 3. Post-process
    # Bounds
    if !isnothing(d.min) && !isnothing(d.max)
        val = clamp.(val, d.min, d.max)
    end

    # Normalize
    if d.normalize
        s = sum(val)
        if s > 0
            val = val ./ s
        end
    end

    d.data = val
    return d
end

# Helper for context sampling
function sample!(context::NamedTuple, N::Int; random=nothing, force=true)
    # Topological sort
    # We need to sample in order so dependencies are ready.
    # Reusing the logic from old core.jl but adapted to new struct

    order = get_dependency_order(context)
    for k in order
        v = context[k]
        if v isa SEDist
            if force || isempty(v.data)
                sample!(v, N; context=context, random=random)
            end
        end
    end

    return context
end

function sample!(context::NamedTuple; N::Union{Nothing,Int}=nothing, random::Union{Nothing,Bool}=nothing, force=true)
    if isnothing(N)
        if haskey(context, :N)
            N = context.N
        else
            error("Provide N=... or include :N in the context NamedTuple")
        end
    end
    return sample!(context, N; random=random, force=force)
end

# Dependency Graph Implementation
function get_dependency_order(context)
    # Identify nodes
    nodes = [k for (k, v) in pairs(context) if v isa SEDist]

    # Build edges
    edges = Dict{Symbol,Vector{Symbol}}()
    for k in nodes
        d = context[k]
        deps = Symbol[]
        if d.dependency isa FunctionalDependency
            append!(deps, d.dependency.inputs)
        end
        # Filter only internal nodes
        filter!(x -> x in nodes, deps)
        edges[k] = deps
    end

    # Topological Sort
    # Kahn's algorithm
    in_degree = Dict(k => 0 for k in nodes)
    for (k, deps) in edges
        for d in deps
            in_degree[k] += 1 # Wait, dependency is d -> k. So k depends on d.
            # If k depends on d, d must come before k.
            # Edges: k -> deps (k needs deps).
            # So deps are "parents".
        end
    end

    # Wait, standard topo sort uses edges u -> v where u comes before v.
    # Here edges[k] = [d1, d2]. k depends on d1, d2.
    # So d1 -> k, d2 -> k.

    # Let's build the graph: Parent -> Children
    graph = Dict(k => Symbol[] for k in nodes)
    in_degree = Dict(k => 0 for k in nodes)

    for k in nodes
        for d in edges[k] # d is a dependency of k
            push!(graph[d], k)
            in_degree[k] += 1
        end
    end

    queue = [k for k in nodes if in_degree[k] == 0]
    order = Symbol[]

    while !isempty(queue)
        u = popfirst!(queue)
        push!(order, u)

        for v in graph[u]
            in_degree[v] -= 1
            if in_degree[v] == 0
                push!(queue, v)
            end
        end
    end

    if length(order) != length(nodes)
        error("Cycle detected in dependencies")
    end

    return order
end

# --- Array Interface ---
Base.size(d::SEDist) = size(d.data)
Base.getindex(d::SEDist, i...) = getindex(d.data, i...)
Base.setindex!(d::SEDist, v, i...) = setindex!(d.data, v, i...)
Base.similar(d::SEDist, T::Type, dims::Dims) = similar(d.data, T, dims) # Simplified
Base.iterate(d::SEDist, state...) = iterate(d.data, state...)



# --- Legacy / Helpers ---
# Re-export what's needed
const Dist = SEDist # Alias for backward compatibility? Or just replace usage?
# The user code uses `dist(...)` which returns `SEDist`.
# But type annotations might use `Dist`.
# So `const Dist = SEDist` is good.

# Helper for dependency graph plotting (used in plots.jl)
function dependency_graph(s)
    # Return format expected by plots.jl: (; nodes, edges, order)
    nodes = [k for (k, v) in pairs(s) if v isa SEDist]
    edges = Dict{Symbol,Vector{Symbol}}()
    for k in nodes
        d = s[k]
        deps = Symbol[]
        if d.dependency isa FunctionalDependency
            append!(deps, d.dependency.inputs)
        end
        filter!(x -> x in nodes, deps)
        edges[k] = deps
    end
    order = get_dependency_order(s)
    return (; nodes, edges, order)
end
