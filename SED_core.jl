using Statistics, Distributions, OrdinaryDiffEq, Random
using LinearAlgebra
using DataFrames, GLM, StatsModels
using DiffEqCallbacks: TerminateSteadyState
import Base: show
using Base: @kwdef

# ODE	setup
begin 

    function dxdt(dx, x, p, t)

        # Extract parameters to make equations prettier
        N = p.N
        # Actor resource use change
        dx[1:N] = p.α .* (x[N+1] .- p.γ(x, p, t))

        # Resource level dynamics
        dx[N+1] = x[N+1] * ((1 - x[N+1]) - sum(x[1:N]))

        # Optional function to add functionality, e.g. markets
        p.ϕ(dx, x, p, t)
    end

    # This ensures constrained values of variables, e.g. 0>uᵢ>ū
    function stage_limiter!(x, integrator, p, t)
        # Actor use limits
        x[1:p.N] .= ifelse.(x[1:p.N] .< 0.0, 0.0,
            ifelse.(x[1:p.N] .> (p.μ(x, p, t)), p.μ(x, p, t), x[1:p.N]))

        for j in p.N+1:length(x)
            x[j] = max(0.0, x[j])
        end
    end

    # Solve ODE
    function sim(s; u0=zeros(s.N), y0=1.0, ϕ0=0.0, regulation=0.0, start_from_OA=false, t_end=1000.0)
        isempty(s.w̃.data) ? sample!(s.w̃, s.N) : nothing
        isempty(s.ū.data) ? sample!(s.ū, s.N) : nothing
        tspan = (0.0, t_end)
        p = s.regulate(s, regulation)

        if s.policy == "Tradable Use Rights"
            initVals = [u0; y0; ϕ0]
        elseif s.policy == "Protected Area Two Pop"
            initVals = [u0; y0; y0]
        else
            initVals = [u0; y0]
        end

        if start_from_OA
            oa = p.regulate(p, 0.0)
            oaprob = ODEProblem(dxdt, initVals, tspan, oa)
            oasol = solve(oaprob, SSPRK432(; stage_limiter!), callback=TerminateSteadyState(1e-6, 1e-4))
            initVals[1:oa.N+1] = oasol[1:oa.N+1, end-2]
        end

        prob = ODEProblem(dxdt, initVals, tspan, p)
        sol = solve(prob, SSPRK432(; stage_limiter!), callback=TerminateSteadyState(1e-6, 1e-4))
        return sol
    end

end

# ------------------------------------------------------------
# Regulation scan (policy evaluation helper)
# ------------------------------------------------------------

"""
    regulation_scan(p; m=100)

Scan regulation in [0,1) with `m` steps for a given scenario `p`.
Returns a NamedTuple with arrays for resource revenues (RR), wages (WR), trade (TR),
total revenues (ToR), inequality (GI), ecological status (EH), a simple governance score (Gov),
and the index of the optimum per metric (oRR, oWR, oTR, oToR, oGI, oEH, oGov).
"""
function regulation_scan(p; m=100)
    r = range(0.0, stop=1.0 - 1.0/m, length=m)
    RR = zeros(m); WR = zeros(m); TR = zeros(m); ToR = zeros(m)
    GI = zeros(m); EH = zeros(m); Gov = zeros(m)
    # baseline for behaviour change (optional)
    oau = zeros(p.N)
    for (j, reg) in enumerate(r)
        sol = sim(p, regulation=reg, t_end=1000.0)
        inc = incomes(sol)
        RR[j] = sum(inc.resource)
        WR[j] = sum(inc.wages)
        TR[j] = sum(inc.trade)
        ToR[j] = sum(inc.total)
        GI[j] = inc.gini
        EH[j] = inc.ecological
        # a simple governance score (tunable): higher R and T, lower inequality
        Gov[j] = (RR[j])^0.5 * (ToR[j])^1.0 * (1 .- GI[j])^0.2 * (EH[j])^0.0
        # store OA baseline on first iteration (approximate)
        if j == 1
            oau .= sol[1:p.N, end-1]
        end
    end
    oRR   = argmax(RR)
    oWR   = argmax(WR)
    oTR   = argmax(TR)
    oToR  = argmax(ToR)
    oGI   = argmin(GI)
    oEH   = argmax(EH)
    oGov  = argmax(Gov)
    (; r, RR, WR, TR, ToR, GI, EH, Gov, oRR, oWR, oTR, oToR, oGI, oEH, oGov)
end

# Γ Φ incomes and gini definitions
begin 

    function Γ(y, p; x=zeros(p.N + 1), t=0.0)
        x[p.N+1] = y
        γ = p.γ(x, p, t)
        id = sortperm(γ) # if w_bar's are not in ascending order
        f = sum(γ[id] .< y) / p.N
    end

    # Impact function
    function Φ(y, p; t=0.0)
        x = zeros(p.N + 1)
        x[end] = y
        γ = p.γ(x, p, t)

        id = sortperm(γ)
        μ = p.μ(x, p, t)
        cu = cumsum(μ[id])
        f = sum(cu .< (1.0 - y))
        if f == 0
            f = (1.0 - y) / μ[id[1]]
        elseif f < p.N
            f = f + ((1 - y) - cu[f]) / μ[id[f+1]]
        end
        return f / p.N
    end


    # -- income calculation, with dimensional toggle --
    function incomes(x, p; summarize=false, dimensional::Bool=false)
        # --- unpack state and parameters ---
        y = x[p.N+1]
        u = x[1:p.N]
        f = occursin("Protected Area", p.policy) ? p.regulation : 0.0

        # nondimensional revenues
        resource_nd = u .* y .* (1 .- f)
        μ = p.μ(x, p, 0.0)
        γ = occursin("Protected Area", p.policy) || occursin("Exclusive Use Rights", p.policy) || occursin("Tradable Use Rights", p.policy) ? p.w̃ : p.γ(x, p, 0.0) #we used the scaling in the gammafunciton for PA, which works for incentives but screws up incomes....
        wages_nd = (μ .- u) .* γ
        wages_0_nd = μ .* γ
        # wages_nd    = (p.ū .- u) .* p.w̃ #occursin("Protected Area", p.policy) ? (p.μ(x,p,1.0) .- u) .* p.γ(x,p,1.0) : (p.ū .- u) .* p.w̃
        #trade_nd    = p.policy == "Tradable Use Rights" ? (p.R .- u) .* x[p.N+2] : zeros(p.N)

        if p.policy == "Tradable Use Rights"
            if p.policy_target == :yield
                trade_nd = (p.R .- (u .* y)) .* x[p.N+2]
            else   # effort-based
                trade_nd = (p.R .- u) .* x[p.N+2]
            end
        else
            trade_nd = zeros(p.N)
        end

        total_nd = resource_nd .+ wages_nd .+ trade_nd

        # gini and ecology always nondimensional
        g = gini(total_nd)
        ecological = y

        if dimensional
            # apply dimensional scaling factor once
            # you must have p.rpk = r * p * K stored in your scenario
            scale = p.rpk
            resource = resource_nd .* scale
            wages = wages_nd .* scale
            wages_0 = wages_o_nd .* scale
            trade = trade_nd .* scale
            total = total_nd .* scale
        else
            resource, wages, trade, total, wages_0 = resource_nd, wages_nd, trade_nd, total_nd, wages_0_nd
        end

        out = (; resource, wages, trade, total,
            gini=g,
            ecological, wages_0)
        return summarize ? merge(out, (; g=g, ecological=ecological)) : out
    end

    # convenience overload for full solution
    incomes(sol::ODESolution) = incomes(sol.u[end], sol.prob.p)

    function gini(x)
        sum([abs(x[i] - x[j]) for i in 1:length(x), j in 1:length(x)]) / (2 * length(x) * sum(x))
    end

end

# Minimal policy functions and scenario builders
begin
    # Open Access policy primitives
    function γ(x, p, t)
        return hasproperty(p, :w̃) && hasproperty(p.w̃, :data) ? p.w̃.data : p.w̃
    end
    function μ(x, p, t)
        return hasproperty(p, :ū) && hasproperty(p.ū, :data) ? p.ū.data : p.ū
    end
    ϕ(dx, x, p, t) = nothing
    regulate(p, f) = p

    # Scenario builder (policy can override later)
    function scenario(p; kwargs...)
        temp = (; p..., policy="Open Access", γ=γ, μ=μ, ϕ=ϕ, regulate=regulate, kwargs...)
        return (; temp...)
    end

    function base(; N=100, sigma=0.0, random=false)
        (; N,
         α=0.1,
         w̃=dist(min=0.1, max=1.0, distribution=LogNormal, random=random),
         ū=dist(mean=1.0, sigma=sigma, normalize=true, random=random),
         R=ones(N), γ, μ, ϕ, regulate, policy="Open Access")
    end

    function high_impact(; N=100, sigma=0.0)
        (; N, α=0.1,
         w̃=dist(min=0.01, max=1.0, distribution=LogNormal),
         ū=dist(mean=2.0, sigma=sigma, normalize=true),
         R=ones(N), γ, μ, ϕ, regulate, policy="Open Access")
    end

    function low_impact(; N=100, sigma=0.0)
        (; N, α=0.1,
         w̃=dist(min=0.01, max=0.6, distribution=LogNormal),
         ū=dist(mean=0.5, sigma=sigma, normalize=true),
         R=ones(N), γ, μ, ϕ, regulate, policy="Open Access")
    end

    function high_incentives(; N=100, sigma=0.0)
        (; N, α=0.1,
         w̃=dist(min=0.3, max=0.7, distribution=LogNormal),
         ū=dist(mean=1.0, sigma=sigma, normalize=true),
         R=ones(N), γ, μ, ϕ, regulate, policy="Open Access")
    end
end

# SED the distributional feature
begin 
		#
		# This module provides a type `SED` for generating socio‐economic distributions
    # that can optionally depend on other variables. Dependencies are now resolved
    # by passing in a context (a NamedTuple containing all SEDs), rather than by a
    # global lookup. In addition, you can specify a custom dependency relationship.
    #
    # For example, you can write:
    #
    #     w̃ = sed(dependent=(ē = 1.0, q = 1.0, r = 1.0, fun = (dep -> (dep.ē * dep.q) / dep.r)),
    #              min = 0.1, max = 0.2, distribution = LogNormal)
    #
    # and later call `sample!(w̃, N, context)` where `context` is a NamedTuple containing
    # w̃ and the SEDs named `ē`, `q`, and `r`.
    #
    # Written with clarity, type safety, and efficiency in mind.
    # =============================================================================


    # Explicitly import functions from Statistics to avoid ambiguity.
    #import Statistics: mean, median, std, var

    # -----------------------------------------------------------------------------
    # Basic Data Types
    # -----------------------------------------------------------------------------
    import Statistics: mean, median, std, var
    """
        Derived(data::Vector{Float64})

    A simple wrapper type representing a distribution derived from data.
    """
    struct Derived <: ContinuousUnivariateDistribution
        data::Vector{Float64}
    end

    """
        Data(data::Vector{Float64})

    A simple wrapper type representing a distribution constructed directly from data.
    """
    struct Data <: ContinuousUnivariateDistribution
        data::Vector{Float64}
    end

    # Extend statistical functions to work on Derived and Data.
    mean(d::Union{Derived,Data}) = Statistics.mean(d.data)
    median(d::Union{Derived,Data}) = Statistics.median(d.data)
    std(d::Union{Derived,Data}) = Statistics.std(d.data)
    var(d::Union{Derived,Data}) = Statistics.var(d.data)
    Constant = Dirac

    # -----------------------------------------------------------------------------
    # SED Type Definition
    # -----------------------------------------------------------------------------

    """
        Dist{T, N, A<:AbstractArray{T, N}} <: AbstractArray{T, N}

    A container for a (stochastic or deterministic) distribution with optional
    dependencies on other variables.

    # Fields
    - `data::A`: Array holding the generated values.
    - `min, max, mean, median, sigma, sum`: Optional distribution parameters.
    - `random::Bool`: If `true`, generate data randomly (using `rand`); otherwise by quantiles.
    - `normalize::Bool`: If `true`, normalize the generated data.
    - `dependent::NamedTuple`: Specifies dependencies. In the simplest case each key (other than `fun`)
       is taken as a coefficient for the corresponding variable. If a key `:fun` is present, its value
       (which must be a function) is used to compute the dependent contribution.
    - `distribution`: The base distribution type (e.g. `Uniform`, `LogNormal`, etc.).
          - `dependency_function::Union{Function,AbstractString,Nothing}`: A function or expression that
             combines the independent data with the dependent contribution. (Default: elementwise
             addition.) If a `String`, variables in `dependent` (or inferred from the string) and `sed`
             (the independent vector) are in scope.
    """
    @kwdef mutable struct Dist{T,N,A<:AbstractArray{T,N}} <: AbstractArray{T,N}
        data::A = nothing
        min::Union{Nothing,Float64} = nothing
        max::Union{Nothing,Float64} = nothing
        mean::Union{Nothing,Float64} = nothing
        median::Union{Nothing,Float64} = nothing
        sigma::Union{Nothing,Float64} = nothing
        sum::Union{Nothing,Float64} = nothing
        random::Bool = false
        normalize::Bool = false
        dependent::NamedTuple = NamedTuple()   # e.g., (ē = 1.0, q = 1.0, r = 1.0, fun = (dep -> (dep.ē * dep.q) / dep.r))
        distribution::Any = Uniform              # e.g., Uniform, LogNormal, etc.
        dependency_function::Union{Function,AbstractString,Nothing} = (indep, dep) -> indep .+ dep
        # Sampling policy options (for lognormal min/max mapping & bounds)
        bounds_quantiles::Tuple{Float64,Float64} = (0.01, 0.99)
        determ_bounds::Symbol = :within      # :within | :full | :clip
        random_bounds::Symbol = :none        # :none | :truncate | :reject (truncate/reject equivalent here)
        enforce_after_deps::Symbol = :none   # :none | :clamp | :truncate
    end

    # -----------------------------------------------------------------------------
    # Helper Functions
    # -----------------------------------------------------------------------------

    """
        change(params::NamedTuple; kwargs...) -> NamedTuple

    Return a new NamedTuple with keys and values from `params` updated by `kwargs`.
    """
    change(params::NamedTuple; kwargs...) = (; params..., kwargs...)

    """
        lognormal_range(min::Float64; stop::Float64 = 1.0, length::Int = 10) -> Vector{Float64}

    Generate `length` values logarithmically spaced between `min` and `stop`.
    If `min` is zero, it is replaced with a small positive value.
    """
    function lognormal_range(min::Float64; stop::Float64=1.0, length::Int=10)
        min = (min == 0.0) ? 0.01 : min
        stop = (min > stop) ? min + 0.01 : stop
        if length == 1
            return [(min + stop) / 2]
        else
            qs = collect(range(1 / length, stop=1 - 1 / length, length=length))
            lr = quantile.(Normal(0.0, 2.0), qs)
            lr .-= lr[1]
            lr ./= lr[end]
            lr .*= (log(stop) - log(min))
            lr .+= log(min)
            return exp.(lr)
        end
    end

    # -----------------------------------------------------------------------------
    # Dependency Resolution
    # -----------------------------------------------------------------------------

    """
        apply_dependencies!(sed::Dist, N::Int, context::NamedTuple) -> sed

    Updates `sed.data` by combining its independent data with a dependent contribution.
    The dependent contribution is computed from the dependency specification in `sed.dependent`
    using the provided `context`. The key `:fun` (if present) is reserved for a custom function
    and is not used to scale dependency variables.
    """
    # Extract dependency symbols from a string expression by finding symbols
    # that also exist as keys in the provided context. Excludes the special
    # identifier `sed` which refers to the independent values.
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
        # Remove special identifiers which are provided by the evaluator
        delete!(syms, :sed)
        delete!(syms, :independent)
        return [s for s in syms if haskey(context, s)]
    end

    # Validate that all identifier-like symbols referenced in the expression are
    # known (either in the context or the special `sed`). Returns a vector of
    # unknown identifiers, if any.
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
        # Allow the special identifiers provided by the evaluator
        delete!(syms, :sed)
        delete!(syms, :independent)
        # Allow selected Base functions used inside expressions
        allowed_funcs = Set([:min, :max, :clamp, :abs, :sqrt, :exp, :log])
        syms = setdiff(syms, allowed_funcs)
        unknown = Symbol[]
        for s in syms
            # filter out operator-like symbols (not identifier names)
            if Base.isidentifier(String(s)) && !haskey(context, s)
                push!(unknown, s)
            end
        end
        return unknown
    end

    function apply_dependencies!(sed::Dist, N::Int, context::NamedTuple)
        # If nothing to apply (no dependent keys and no dependency_function), skip
        if isempty(sed.dependent) && (sed.dependency_function === nothing)
            return sed
        end

        # Collect dependency values for all referenced keys (excluding :fun)
        keys_list = [k for k in keys(sed.dependent) if k != :fun]
        depvals = Dict{Symbol,Any}()
        for k in keys_list
            haskey(context, k) || error("Context does not contain dependency variable $(k)")
            v = context[k]
            depvals[k] = hasproperty(v, :data) ? v.data : v
        end

        # -- Case 1: legacy `:fun` inside `dependent`
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
            # Optional post-dependency enforcement
            if sed.enforce_after_deps != :none && sed.min !== nothing && sed.max !== nothing && sed.max > sed.min
                if sed.enforce_after_deps == :clamp
                    sed.data = clamp.(sed.data, sed.min, sed.max)
                elseif sed.enforce_after_deps == :truncate
                    sed.data = clamp.(sed.data, sed.min, sed.max)
                end
            end
            return sed
        end

        # -- Case 2: dependency_function provided (function or string expression)
        if sed.dependency_function !== nothing
            df = sed.dependency_function
            indep = sed.data
            if df isa Function
                # If there are no dependency values, skip applying a functional
                # dependency_function. This avoids treating the default
                # (indep, dep)-> indep .+ dep as meaningful when no deps exist.
                if isempty(depvals)
                    return sed
                end
                # Try (indep, deps_namedtuple) then (deps_namedtuple) for convenience
                deps_nt = NamedTuple{Tuple(keys(depvals))}(values(depvals))
                try
                    sed.data = df(indep, deps_nt)
                catch
                    sed.data = df(deps_nt)
                end
                # Optional post-dependency enforcement
                if sed.enforce_after_deps != :none && sed.min !== nothing && sed.max !== nothing && sed.max > sed.min
                    if sed.enforce_after_deps == :clamp
                        sed.data = clamp.(sed.data, sed.min, sed.max)
                    elseif sed.enforce_after_deps == :truncate
                        sed.data = clamp.(sed.data, sed.min, sed.max)
                    end
                end
                return sed
            elseif df isa AbstractString
                # Evaluate an expression like "q .* w ./ K .+ sed"
                # If keys_list empty, infer from string and available context keys
                if isempty(keys_list)
                    keys_list = _infer_dep_keys(df, context)
                    for k in keys_list
                        v = context[k]
                        depvals[k] = hasproperty(v, :data) ? v.data : v
                    end
                end
                # Validate that the expression does not reference unknown identifiers
                unknown = _unknown_idents(df, context)
                if !isempty(unknown)
                    available = join(Symbol.(keys(context)), ", ")
                    missing = join(unknown, ", ")
                    error("Unknown variable(s) in dependency_fun: $(missing). Available: $(available). The special name `sed` refers to the base vector.")
                end
                # Parse and rewrite basic ops to broadcasting when vectors are involved
                ex = Meta.parse(df)
                # Determine if an expression is vector-like (contains sed or a dependent symbol)
                function _is_veclike(e)
                    if e === :sed || e === :independent
                        return true
                    elseif e isa Symbol
                        return e in keys_list
                    elseif e isa Expr
                        # If any argument is veclike, propagate
                        for a in e.args
                            if _is_veclike(a)
                                return true
                            end
                        end
                        return false
                    else
                        return false
                    end
                end
                function _broadcast_ops(e)
                    if e isa Expr && e.head == :call
                        op = e.args[1]
                        # Unary minus on veclike: rewrite to elementwise negation
                        if op == :- && length(e.args) == 2
                            a = e.args[2]
                            if _is_veclike(a)
                                return Expr(:call, :.* , -1, _broadcast_ops(a))
                            end
                        end
                        # Elementwise wrappers for selected Base functions
                        if op isa Symbol && (op == :min || op == :max || op == :clamp || op == :abs || op == :sqrt || op == :exp || op == :log)
                            # transform arguments first
                            args = [ _broadcast_ops(arg) for arg in e.args[2:end] ]
                            # If any argument is veclike, wrap in broadcast
                            if any(_is_veclike, args)
                                return Expr(:call, :broadcast, op, args...)
                            else
                                return Expr(:call, op, args...)
                            end
                        end
                        # N-ary ops: +, -, *, /
                        if (op == :+ || op == :- || op == :* || op == :/)
                            # Recursively transform all operands first
                            ops = [ _broadcast_ops(arg) for arg in e.args[2:end] ]
                            # If more than 2 operands, fold left with broadcasted operator when veclike
                            bop = op == :+ ? :.+ : op == :- ? :.- : op == :* ? :.* : :./
                            acc = ops[1]
                            for k in 2:length(ops)
                                a = acc; b = ops[k]
                                if _is_veclike(a) || _is_veclike(b)
                                    acc = Expr(:call, bop, a, b)
                                else
                                    acc = Expr(:call, op, a, b)
                                end
                            end
                            return acc
                        end
                        return Expr(e.head, (_broadcast_ops(arg) for arg in e.args)...)
                    else
                        return e
                    end
                end
                ex = _broadcast_ops(ex)
                assigns = [:($(k) = $(depvals[k])) for k in keys_list]
                let_block = :(
                    let sed = $(indep); independent = $(indep)
                        $(Expr(:block, assigns...))
                        $ex
                    end
                )
                sed.data = Core.eval(@__MODULE__, let_block)
                return sed
            end
        end

        # -- Case 3: default to weighted sum (unit weights if none provided)
        dep_sum = zeros(eltype(sed.data), N)
        for k in keys_list
            dv = depvals[k]
            dep_sum .+= dv
        end
        sed.data = sed.dependency_function(sed.data, dep_sum)
        return sed
    end


    """
        is_distribution_type(sed::Dist, T::DataType) -> Bool

    Returns true if `sed.distribution` is either exactly the bare type `T`
    (or a subtype of `T` when stored as a bare type) or is an instance of `T`.
    """
    function is_distribution_type(sed, dist)
        return sed.distribution == dist || sed.distribution isa dist
    end

    """
        has_dependencies(sed::Dist) -> Bool

    Returns true if the SED has dependencies.
    """
    function has_dependencies(sed::Dist)
        return !isempty(sed.dependent)
    end

    """
        is_property_name(s::Symbol, property_name::Symbol) -> Bool

    Check if a symbol matches a parameter name, handling special cases
    like w̃ and ū.
    """
    function is_property_name(s::Symbol, property_name::Symbol)
        return s == property_name ||
               (s == :w && property_name == :w̃) ||
               (s == :u && property_name == :ū)
    end

    """
        find_dist_by_name(context::NamedTuple, name::Symbol) -> Union{SED, Nothing}

    Find an SED by name in the context, handling special cases for w̃ and ū.
    """
    function find_dist_by_name(context::NamedTuple, name::Symbol)
        for (k, v) in pairs(context)
            if v isa Dist && is_property_name(name, k)
                return v
            end
        end
        return nothing
    end

    # -----------------------------------------------------------------------------
    # Distribution Generation
    # -----------------------------------------------------------------------------

    """
        generate_distribution!(sed::Dist, N::Int) -> sed

    Generate the distribution data for the SED, without applying dependencies.
    """
    function generate_distribution!(sed::Dist, N::Int)
        rev = false  # Flag for reversed quantiles
        # If no distribution parameters are provided but this SED will be
        # computed from dependencies, initialize a zero vector and skip
        # distribution-specific generation. The dependency pass will fill it.
        if sed.min === nothing && sed.max === nothing && sed.mean === nothing &&
           sed.median === nothing && sed.sigma === nothing && sed.sum === nothing &&
           (sed.dependency_function !== nothing || !isempty(sed.dependent))
            sed.data = zeros(eltype(sed.data), N)
            return sed
        end
        if is_distribution_type(sed, LogNormal)
            # LogNormal parameterization: prefer min/max as quantiles if provided
            if sed.min !== nothing && sed.max !== nothing && sed.max != sed.min
                xlo = min(sed.min, sed.max); xhi = max(sed.min, sed.max)
                xlo = xlo <= 0 ? 1e-6 : xlo
                qlo, qhi = sed.bounds_quantiles
                z1 = quantile(Normal(), qlo)
                z2 = quantile(Normal(), qhi)
                σ = (log(xhi) - log(xlo)) / (z2 - z1)
                μ = log(xlo) - σ * z1
                sed.distribution = LogNormal(μ, abs(σ))
            elseif sed.mean !== nothing && sed.sigma !== nothing
                sed.distribution = (sed.sigma != 0.0) ?
                                   LogNormal(log(sed.mean) - abs(sed.sigma)^2 / 2, abs(sed.sigma)) :
                                   Constant(sed.mean)
            elseif sed.median !== nothing && sed.sigma !== nothing
                sed.distribution = (sed.sigma != 0.0) ?
                                   LogNormal(log(sed.median), abs(sed.sigma)) :
                                   Constant(sed.median)
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
            # Uniform branch...
            if sed.min !== nothing && sed.max !== nothing
                rev = sed.min > sed.max
                if sed.max != sed.min
                    sed.distribution = Uniform(minimum((sed.min, sed.max)),
                        maximum((sed.min, sed.max)))
                else
                    sed.distribution = Constant(sed.min)
                end
            elseif sed.mean !== nothing && sed.sigma !== nothing
                rev = sed.sigma < 0
                sed.distribution = (sed.sigma != 0.0) ?
                                   Uniform(sed.mean - abs(sed.sigma) / 2, sed.mean + abs(sed.sigma) / 2) :
                                   Constant(sed.mean)
            elseif sed.median !== nothing && sed.sigma !== nothing
                rev = sed.sigma < 0
                sed.distribution = (sed.sigma != 0.0) ?
                                   Uniform(sed.median - abs(sed.sigma) / 2, sed.median + abs(sed.sigma) / 2) :
                                   Constant(sed.median)
            end
            if sed.random
                sed.data = rand(sed.distribution, N)
            else
                qs = quantile.(Ref(sed.distribution), range(1 / N, stop=1 - 1 / N, length=N))
                sed.data = (N == 1) ? [quantile(sed.distribution, 0.5)] : (rev ? reverse(qs) : qs)
            end
        elseif is_distribution_type(sed, Dirac)
            # Dirac (point mass) at a specified value
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
            # Bernoulli branch: use sed.mean as the probability parameter.
            p = sed.mean !== nothing ? sed.mean :
                error("For Bernoulli, please specify the probability in sed.mean")
            sed.distribution = Bernoulli(p)
            if sed.random
                sed.data = rand(sed.distribution, N)
            else
                # For a discrete distribution like Bernoulli, quantiles are defined (0 or 1)
                qs = quantile.(Ref(sed.distribution), range(1 / N, stop=1 - 1 / N, length=N))
                sed.data = qs
            end
            # ... other branches for ConstantDistribution, Exponential, Beta, etc.

        else
            error("Unsupported distribution type: $(sed.distribution)")
        end

        if sed.normalize
            sed.data .= sed.data ./ N
        end

        return sed
    end

    """
        sample!(sed::Dist, N::Int; context=nothing) -> sed

    Generate (or update) `sed.data` with `N` points using the specified distribution.
    After generating the independent data, apply dependency calculations using the
    provided `context`.
    """
    function sample!(sed::Dist, N::Int; context=nothing, random::Union{Nothing,Bool}=nothing)
        # Optionally override randomness for this call
        old_random = sed.random
        if random !== nothing
            sed.random = random
        end
        try
            # Generate the distribution
            generate_distribution!(sed, N)

            # Apply dependencies if context is provided
            if context !== nothing
                apply_dependencies!(sed, N, context)
            end
        finally
            # Restore prior randomness flag
            sed.random = old_random
        end
        return sed
    end

    """
        sample!(s, param_name::Symbol) -> SED

    Generate distributions for the SED parameter specified by name.
    Uses s.N as the length of the distribution.
    """
    function sample!(s, param_name::Symbol; N::Union{Nothing,Int}=nothing, random::Union{Nothing,Bool}=nothing)
        N === nothing && (N = s.N)
        sed = find_dist_by_name(s, param_name)
        if sed === nothing
            error("Could not find SED parameter named $(param_name) in the scenario")
        end
        return sample!(sed, N; context=s, random)
    end

    """
        sample!(s) -> NamedTuple

    Generate distributions for all SED parameters in the scenario.
    First processes independent SEDs, then dependent ones.
    Uses s.N as the length of the distributions.
    """
    # Build dependency graph for SED fields in a NamedTuple context.
    # Returns (nodes, edges, order), where edges[k] is a Vector of symbols that k depends on,
    # and order is a valid topological ordering of nodes.
    function dependency_graph(s)
        # Robust SED detection: treat as SED if it is the SED type or a struct
        # with fields typical of SED (e.g., :dependent and :dependency_function)
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
                # infer dependencies from expression string
                for dk in _infer_dep_keys(v.dependency_function, s)
                    dk in sedkeys && push!(deps[k], dk)
                end
            end
        end
        indeg = Dict(k => 0 for k in sedkeys)
        for k in sedkeys
            for d in deps[k]
                indeg[k] += 1
            end
        end
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
        length(order) == length(sedkeys) || error("Cyclic SED dependencies detected among: $(setdiff(sedkeys, order))")
        return (; nodes=sedkeys, edges=deps, order)
    end

    function sample!(s; N::Union{Nothing,Int}=nothing, random::Union{Nothing,Bool}=nothing)
        N === nothing && (N = s.N)
        g = dependency_graph(s)
        for k in g.order
            v = getfield(s, k)
            needs_deps = has_dependencies(v) || (v.dependency_function isa AbstractString) ||
                         ((v.dependency_function isa Function) && !isempty(v.dependent))
            if needs_deps
                sample!(v, N; context=s, random)
            else
                sample!(v, N; random)
            end
        end
        return s
    end

    """
        sample!(context::NamedTuple, N::Int) -> NamedTuple

    Applies `sample!(sed, N, context)` to each SED in the provided context and returns
    a new NamedTuple with the updated SEDs.
    """
    function sample!(context::NamedTuple, N::Int; random::Union{Nothing,Bool}=nothing)
        new_context = map(x -> (x isa Dist ? sample!(x, N; context=context, random) : x), context)
        return new_context
    end

    # Keyword form for contexts: sample!(context; N=...)
    function sample!(context::NamedTuple; N::Union{Nothing,Int}=nothing, random::Union{Nothing,Bool}=nothing)
        if N === nothing
            haskey(context, :N) || error("Provide N=... or include :N in the context NamedTuple")
            N = context.N
        end
        return sample!(context, N; random)
    end

    # -----------------------------------------------------------------------------
    # Making SED Behave Like an Array
    # -----------------------------------------------------------------------------

    Base.size(sed::Dist) = size(sed.data)
    Base.getindex(sed::Dist, idx...) = getindex(sed.data, idx...)
    Base.setindex!(sed::Dist, value, idx...) = setindex!(sed.data, value, idx...)

    """
        similar(sed::Dist, ::Type{T}, dims::Dims) -> SED

    Creates a new SED instance with an uninitialized data array of type `T` and dimensions
    `dims`, copying all other parameters from the original.
    """
    function Base.similar(sed::Dist{T,N,A}, ::Type{T}, dims::Dims) where {T,N,A<:AbstractArray{T,N}}
        return Dist(
            data=similar(sed.data, T, dims),
            min=sed.min,
            max=sed.max,
            mean=sed.mean,
            median=sed.median,
            sigma=sed.sigma,
            sum=sed.sum,
            random=sed.random,
            normalize=sed.normalize,
            dependent=sed.dependent,
            distribution=sed.distribution,
            dependency_function=sed.dependency_function
        )
    end

    Base.iterate(sed::Dist, state...) = iterate(sed.data, state...)

    # -----------------------------------------------------------------------------
    # Constructor Function
    # -----------------------------------------------------------------------------

    """
        dist(; data=nothing, min=nothing, max=nothing, kwargs...) -> SED

    Construct a new SED instance. If `data` is provided, its element type and dimensionality
    are used; otherwise, an empty array of type `Float64` is created. Additional keyword arguments
    are passed directly to the SED constructor.
    """
    function dist(; data=nothing, min=nothing, max=nothing, kwargs...)
        kw = (; kwargs...)
        if haskey(kw, :dependency_fun) && !haskey(kw, :dependency_function)
            kw = change(kw; dependency_function=kw.dependency_fun)
            # do not carry dependency_fun forward
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

        # filter to allowed Dist keywords
        allowed = Set([:min, :max, :mean, :median, :sigma, :sum, :random, :normalize, :dependent, :distribution, :dependency_function,
                       :bounds_quantiles, :determ_bounds, :random_bounds, :enforce_after_deps])
        filtered_pairs = [(k => getproperty(kw, k)) for k in keys(kw) if k in allowed]
        filtered_kw = (; filtered_pairs...)

        T = Float64
        ND = 1
        A = Array{T,ND}
        if data !== nothing
            T = eltype(data)
            ND = ndims(data)
            A = typeof(data)
        else
            data = Array{T,ND}(undef, 0)
        end
        return Dist{T,ND,A}(; data, min, max, filtered_kw...)
    end

    # -----------------------------------------------------------------------------
    # Pretty printing
    # -----------------------------------------------------------------------------

    """
        astext(d::Dist) -> String

    Return a human‑readable summary of a `Dist`, including distribution, parameters,
    dependency info, and data summary (length/min/max when present).
    """
    function astext(d::Dist)
        b = IOBuffer()
        show(b, MIME"text/plain"(), d)
        String(take!(b))
    end

    function Base.show(io::IO, d::Dist)
        # compact 1‑line summary
        distname = try nameof(typeof(d.distribution)) catch; string(typeof(d.distribution)) end
        ndata = (d.data isa AbstractArray) ? length(d.data) : 0
        print(io, "Dist($distname, length=$ndata)")
    end

    function Base.show(io::IO, ::MIME"text/plain", d::Dist)
        distname = try nameof(typeof(d.distribution)) catch; string(typeof(d.distribution)) end
        println(io, "Dist(")
        println(io, "  distribution : ", distname)
        println(io, "  params       : ", "min=", d.min, ", max=", d.max, ", mean=", d.mean,
                ", median=", d.median, ", sigma=", d.sigma, ", sum=", d.sum)
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
            println(io, "  data         : length=", length(d.data), ", eltype=", eltype(d.data),
                    ", min=", dmin, ", max=", dmax)
        else
            println(io, "  data         : ∅ (not sampled)")
        end
        print(io, ")")
    end

end
