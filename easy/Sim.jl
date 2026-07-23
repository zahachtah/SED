module EasySED

include(joinpath(@__DIR__, "..", "SED.jl"))
using .SED

export SED, D, P, custom_policy, scenario, simulate, scan, suite, outcome, setpolicy

const D = SED.dist
const _scan_keys = (:kR, :kT, :kG, :kE, :kI, :warmstart)
_pick(nt, keys) = (; (k => nt[k] for k in keys if haskey(nt, k))...)
_drop(nt, keys) = (; (k => v for (k, v) in pairs(nt) if !(k in keys))...)

struct HookPolicy <: SED.AbstractPolicy
    name::Symbol
    cost::Function
    limit::Function
    dynamics::Function
    apply::Function
    income::Function
    resource::Function
end

_id_cost(v, x, p, t) = v
_id_limit(v, x, p, t) = v
_noop(dx, x, p, t) = nothing
_reg(s, f) = SED.change(s, regulation=f)
_zero_income(x, p, t) = zeros(p.N)
_one_resource(x, p, t) = 1.0

function custom_policy(name=:custom; cost=_id_cost, limit=_id_limit, dynamics=_noop,
        regulate=_reg, income=_zero_income, resource=_one_resource)
    HookPolicy(Symbol(name), cost, limit, dynamics, regulate, income, resource)
end

SED.cost(v, x, p, t, pol::HookPolicy) = pol.cost(v, x, p, t)
SED.limit(v, x, p, t, pol::HookPolicy) = pol.limit(v, x, p, t)
SED.dynamics(dx, x, p, t, pol::HookPolicy) = pol.dynamics(dx, x, p, t)
function SED.regulate(s, f, pol::HookPolicy)
    s2 = pol.apply(s, f)
    SED.change(s2; policy=pol, regulation=f,
        income_extra_fun=pol.income, resource_factor_fun=pol.resource)
end

_norm(x) = replace(lowercase(String(Symbol(x))), r"[^a-z0-9]+" => "_")

function P(kind=:open; target=:effort, market_rate=0.05, buyer_bias=0.0,
        historical=false, historical_use_rights=historical, selector=:top,
        reverse=false, m=0.3, method=:multiplicative, μ_value=0.5, γ_value=0.5,
        kwargs...)
    kind isa SED.AbstractPolicy && return kind
    k = _norm(kind)
    k in ("open", "open_access", "oa") && return SED.OpenAccess()
    k in ("tur", "tradable", "tradable_use_rights") &&
        return SED.TradableUseRights(Symbol(target), Float64(market_rate), Float64(buyer_bias), Bool(historical_use_rights))
    k in ("eur", "exclusive", "exclusive_use_rights") &&
        return SED.ExclusiveUseRights(Symbol(selector), Bool(reverse))
    k in ("pa", "protected", "protected_area") && return SED.ProtectedArea(Float64(m))
    k in ("pa2", "protected_area_two_pop", "protected_area_two_population") &&
        return SED.ProtectedAreaTwoPop(Float64(m))
    k in ("ei", "economic", "economic_incentives") &&
        return SED.EconomicIncentives(Symbol.(target isa Symbol ? [target] : target), Symbol(method))
    k in ("dev", "development") && return SED.Development(Float64(μ_value), Float64(γ_value))
    error("Unknown policy '$kind'. Use :open, :tur, :eur, :pa, :pa2, :ei, :dev, or pass custom_policy(...).")
end

function _base(kind; N=100, sigma=0.0, random=false)
    kind isa NamedTuple && return kind
    k = _norm(kind)
    k == "base" && return SED.base(; N, sigma, random)
    k in ("high", "high_impact") && return SED.high_impact(; N, sigma)
    k in ("low", "low_impact") && return SED.low_impact(; N, sigma)
    k in ("incentives", "high_incentives") && return SED.high_incentives(; N, sigma)
    error("Unknown preset '$kind'.")
end

function scenario(; preset=:base, N=100, sigma=0.0, random=false,
        policy=:open, vars=(;), sample=true, kwargs...)
    s = SED.scenario(_base(preset; N, sigma, random); vars..., policy=P(policy; kwargs...), kwargs...)
    sample && SED.sample!(s; force=false)
    return s
end

setpolicy(s, policy=:open; kwargs...) = SED.scenario(s; policy=P(policy; kwargs...), kwargs...)

function simulate(s=scenario(); policy=nothing, regulation=0.0, t_end=1000.0, kwargs...)
    p = isnothing(policy) ? s : setpolicy(s, policy; kwargs...)
    SED.sim(p; regulation, t_end)
end
run(args...; kwargs...) = simulate(args...; kwargs...)

function scan(s=scenario(); policy=nothing, m=80, kwargs...)
    popts = _drop(kwargs, _scan_keys)
    sopts = _pick(kwargs, _scan_keys)
    SED.regulation_scan(isnothing(policy) ? s : setpolicy(s, policy; popts...); m, sopts...)
end

function outcome(sol; dimensional=false)
    inc = SED.incomes(sol.u[end], sol.prob.p; dimensional)
    (; resource=sum(inc.resource), wages=sum(inc.wages), extra=sum(inc.extra),
      total=sum(inc.total), gini=inc.gini, ecology=inc.ecological, policy=sol.prob.p.policy)
end
summary(args...; kwargs...) = outcome(args...; kwargs...)

function suite(s=scenario(); policies=[
        "Open access" => :open,
        "EUR high AIO excluded" => (:eur, (; selector=:top)),
        "EUR low AIO excluded" => (:eur, (; selector=:bottom)),
        "TUR effort" => (:tur, (; target=:effort)),
        "TUR yield" => (:tur, (; target=:yield)),
        "Protected area" => :pa,
    ], m=80, kwargs...)
    map(policies) do item
        label, spec = item
        kind, opts = spec isa Tuple ? spec : (spec, (;))
        scen = setpolicy(s, kind; opts...)
        (; label, scenario=scen, scan=SED.regulation_scan(scen; m, kwargs...))
    end
end

end
