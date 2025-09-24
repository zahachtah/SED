module SEDContext
import Base: getindex
import ..SEDist: dist!

export @dep, Context

"""
    DepSpec

Internal type representing a dependent specification created by `@dep`.
Holds a list of dependency symbols and an evaluator closure `(get, N) -> Vector`.
"""
struct DepSpec
    deps::Vector{Symbol}
    eval::Function
end

"""
    Context(specs::NamedTuple; N=nothing)

Container for primary and dependent specifications.

- Primaries: `sed(...)`, numbers (broadcast), or vectors of length `N`.
- Dependents: created with `@dep (a,b,...) -> expr` where `a,b,...` are upstream variables.

Call `dist!(ctx; N)` to materialize in topological order, then access with `ctx[:name]`.

Example
    N = 100
    ctx = Context((
        q = sed(min=1/N, max=1/N, normalize=true),
        w = sed(min=0.2, max=0.4),
        K = 2.0,
        w̃ = @dep (q, w, K) -> q .* w ./ K,
    ))
    dist!(ctx; N=N)
    ctx[:w̃]
"""
mutable struct Context
    specs::NamedTuple
    values::Dict{Symbol, Any}
    N::Union{Nothing, Int}
end

Context(specs::NamedTuple; N=nothing) = Context(specs, Dict{Symbol,Any}(), N)

getindex(ctx::Context, s::Symbol) = get(ctx.values, s, nothing)

"""
    __realize_sed__(s::SEDist.SED, N) -> Vector

Helper: realize a `SED` to concrete data of length `N` without exposing a draw API.
"""
function __realize_sed__(s::SEDist.SED, N::Int)
    SEDist.dist!(s, N)
    return s.data
end

"""
    __ensure_vec__(x, N) -> Vector

Coerce numbers to a length-`N` vector. Pass vectors through (with length check).
Realize `SED` via `__realize_sed__`.
"""
function __ensure_vec__(x, N::Int)
    if x isa Number
        return fill(x, N)
    elseif x isa AbstractVector
        length(x) == N || throw(ArgumentError("dependent expression returned length $(length(x)); expected $N"))
        return x
    elseif x isa SEDist.SED
        return __realize_sed__(x, N)
    else
        throw(ArgumentError("unsupported dependent result of type $(typeof(x))"))
    end
end

"""
    @dep (a, b, ...) -> expr

Define a dependent spec computed from already realized upstream variables
`a, b, ...`. You can include `sed(...)` inline; it is realized to a vector of
length `N` automatically at evaluation.

Examples
    w̃ = @dep (q, w, K) -> q .* w ./ K
    ū  = @dep (q, w̃)    -> q ./ w̃ .+ sed(min=0.05, max=0.10)
"""
macro dep(fn)
    # Expect (args...) -> body
    if !(fn isa Expr && fn.head == :->)
        return :(error("@dep expects an anonymous function like (a,b)->body"))
    end
    args_expr, body = fn.args[1], fn.args[2]

    # Normalize args into a Vector{Symbol}
    deps = Symbol[]
    if args_expr isa Symbol
        push!(deps, args_expr)
    elseif args_expr isa Expr && args_expr.head == :tuple
        for a in args_expr.args
            a isa Symbol || return :(error("@dep arguments must be symbols"))
            push!(deps, a)
        end
    else
        return :(error("@dep arguments must be a symbol or a tuple of symbols"))
    end

    # Transform body: wrap sed(...) calls -> __realize_sed__(sed(...), __N__)
    function wrap_sed_calls(ex)
        if ex isa Expr
            if ex.head == :call && ex.args[1] === :sed
                return :(SEDContext.__realize_sed__($(Expr(:call, :sed, ex.args[2:end]...)), __N__))
            else
                return Expr(ex.head, map(wrap_sed_calls, ex.args)...)
            end
        else
            return ex
        end
    end
    wrapped_body = wrap_sed_calls(body)

    # Build evaluator closure: (get, N) -> let a=get(:a), ...; __ensure_vec__(body, N) end
    get_bindings = [:($d = get($(QuoteNode(d)))) for d in deps]
    eval_fn = :( (get, __N__) -> begin
                    $(Expr(:block, get_bindings...))
                    SEDContext.__ensure_vec__($wrapped_body, __N__)
                end )

    return :(SEDContext.DepSpec($(deps), $eval_fn))
end

"""
    dist!(ctx::Context; N)

Realize all specs in dependency order. Scalars broadcast to length `N`.
`SED` primaries are realized by `SEDist.dist!`.
"""
function dist!(ctx::Context; N::Union{Nothing,Int}=ctx.N)
    N === nothing && throw(ArgumentError("provide N either in Context(...; N) or dist!(ctx; N=...)"))
    ctx.N = N

    specs = ctx.specs
    names = collect(keys(specs))

    # Build adjacency and in-degree
    deps_map = Dict{Symbol, Vector{Symbol}}()
    indeg = Dict{Symbol, Int}()
    for name in names
        spec = getfield(specs, name)
        if spec isa DepSpec
            deps_map[name] = spec.deps
            indeg[name] = length(spec.deps)
        else
            deps_map[name] = Symbol[]
            indeg[name] = 0
        end
    end

    # Kahn's algorithm
    ready = Symbol[name for name in names if indeg[name] == 0]
    processed = Symbol[]
    while !isempty(ready)
        n = popfirst!(ready)
        push!(processed, n)

        spec = getfield(specs, n)
        if spec isa DepSpec
            # resolver for dependencies
            getfn = s::Symbol -> begin
                haskey(ctx.values, s) || throw(ArgumentError("dependency $(s) not realized when evaluating $(n)"))
                ctx.values[s]
            end
            ctx.values[n] = spec.eval(getfn, N)
        elseif spec isa SEDist.SED
            ctx.values[n] = __realize_sed__(spec, N)
        elseif spec isa Number
            ctx.values[n] = fill(spec, N)
        elseif spec isa AbstractVector
            length(spec) == N || throw(ArgumentError("spec $(n) has length $(length(spec)); expected $N"))
            ctx.values[n] = spec
        else
            ctx.values[n] = spec
        end

        # reduce in-degree of dependents
        for m in names
            if m != n && (specs[m] isa DepSpec) && (n in deps_map[m])
                indeg[m] -= 1
                if indeg[m] == 0
                    push!(ready, m)
                end
            end
        end
    end

    if length(processed) != length(names)
        remaining = setdiff(names, processed)
        throw(ArgumentError("cyclic or unresolved dependencies among: $(remaining)"))
    end

    return ctx
end

end # module
