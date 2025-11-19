# Adapted policy instrument implementations compatible with current Dist/sim APIs.

using OrdinaryDiffEq
using DiffEqCallbacks: TerminateSteadyState

export with_policy, exclusive_use_rights_kit, exclusive_use_rights_by_opportunities_kit,
    tradable_use_rights_kit, protected_area_kit, economic_incentives_kit, development_kit

# ===== Open Access defaults are defined in core (γ, μ, ϕ, regulate) =====

# ===== Assigned/Exclusive Use Rights =====

function γ_exclusive_use_rights(val, x, p, t)
    return val .+ p.R
end

function regulate_exclusive_use_rights(scenario, f)
    R = zeros(scenario.N)
    n = Int64(round(f * scenario.N))
    if n > 0
        if haskey(scenario, :reverse) && scenario.reverse
            R[max(1, length(R) - n + 1):end] .= 1.0
        else
            R[1:n] .= 1.0
        end
    end
    return change(scenario, R=R) # assign use rights
end

# ===== Tradable Use Rights =====

function regulate_tradable_use_rights(s, f)
    # Default allocation: equal shares of allowed effort or yield
    R = fill(f == 0 ? 1.0 : (1 - Float64(f)) / s.N, s.N)

    if haskey(s, :historical_use_rights)
        # Solve OA once to estimate historical baselines
        u0 = zeros(s.N)
        y0 = 1.0
        ϕ0 = 0.0
        oaprob = ODEProblem(dxdt, [u0; y0; ϕ0], (0.0, 1000.0), s)
        oasol = solve(oaprob, SSPRK432(; stage_limiter!), callback=TerminateSteadyState(1e-6, 1e-4))
        if s.policy_target == :yield
            hist_u = oasol[1:s.N, end-1]
            hist_y = oasol[s.N+1, end-1]
            hist_yield = hist_u .* hist_y
            total_hist_yield = sum(hist_yield)
            if total_hist_yield > 0
                R = hist_yield .* (1 - f) ./ total_hist_yield
            end
        else
            hur = oasol[1:s.N, end-1] .> 0.0
            denom = sum(hur)
            if denom > 0
                R = hur .* (1 - f) ./ denom
            end
        end
    end
    # attach income_extra_fun to reflect trade revenues at incomes time
    function _tur_income_extra(x, p, t)
        u = x[1:p.N]
        y = x[p.N+1]
        if p.policy_target == :yield
            (p.R .- (u .* y)) .* x[p.N+2]
        else
            (p.R .- u) .* x[p.N+2]
        end
    end
    return change(s, R=R, regulation=f, income_extra_fun=_tur_income_extra)
end

function γ_tradable_use_rights(val, x, p, t)
    return val .+ x[end]
end

function ϕ_tradable_use_rights(dx, x, p, t)
    # Supply definition note:
    # We intentionally use aggregate clamping: clamp(sum(R - usage), 0, Inf).
    # Rationale: in a pooled rights market, net slack (after offsetting
    # overuse and underuse across agents) should determine market supply.
    # Element-wise clamping (sum(clamp.(...))) counts any local underuse as
    # supply even if other agents overuse more, which tends to misprice
    # scarcity and destabilize the price dynamics.
    # This aggregate form matches legacy behavior and improves stability.
    supply = if p.policy_target == :yield
        # supply in yield units
        clamp(sum(p.R .- (x[1:p.N] .* x[p.N+1])), 0.0, Inf)
    elseif p.policy_target == :effort
        # supply in effort units
        max(0.0, sum(p.R .- x[1:p.N]))
    else
        0.0
    end
    id = findall((dx[1:p.N] .> 0.0))
    ind_demand = if p.policy_target == :yield
        # demand in yield units
        max_extra_yield = (p.ū[id] .- x[id]) .* x[p.N+1]
        desired_extra_yield = dx[id] .* x[p.N+1]
        min.(max_extra_yield, desired_extra_yield)
    else
        # demand in effort units
        min.(p.ū[id] - x[id], dx[id])
    end
    # Socioeconomic buying power weighting based on opportunities (AIO)
    bias = hasproperty(p, :buyer_bias) ? Float64(getfield(p, :buyer_bias)) : 0.0
    if bias != 0.0 && hasproperty(p, :opportunities)
        opp = getfield(p, :opportunities)
        oppv = hasproperty(opp, :data) ? opp.data : opp
        if length(oppv) == p.N
            omin = minimum(oppv)
            omax = maximum(oppv)
            rng = omax - omin
            if rng > 0
                norm = (oppv .- omin) ./ rng             # [0,1]
                s = 2 .* (norm .- 0.5)                   # [-1,1]
                wfull = clamp.(1 .+ bias .* s, 0.001, Inf)
                ind_demand = ind_demand .* wfull[id]
            end
        end
    end
    demand = sum(ind_demand)
    dx[p.N+2] = p.market_rate * (demand - supply)
    if demand > supply && demand > 0
        if p.policy_target == :yield
            # rationed increment computed in yield units; convert back to effort
            y = max(eps(), x[p.N+1])
            dx[id] .= (supply .* ind_demand ./ demand) ./ y
        else
            dx[id] .= supply .* ind_demand ./ demand
        end
    end
end

# ===== Protected Area Two Populations =====

function ϕ_protected_area_two_pop(dx, x, p, t)
    mx = x[p.N+2] - x[p.N+1]
    dx[p.N+2] = (1.0 - x[p.N+2]) * dx[p.N+2] - (1.0 - p.regulation) / p.regulation * p.m * mx
    dx[p.N+1] += p.regulation / (1.0 - p.regulation) * p.m * mx
end

function γ_protected_area_two_pop(val, x, p, t)
    return val
end

function μ_protected_area_two_pop(val, x, p, t)
    y_u = x[p.N+1]
    y_p = x[p.N+2]
    r_s_local = ((1.0 - p.regulation) / p.regulation) * p.m * (y_p - y_u) / y_u
    return val .* (1 .+ r_s_local) .^ (-1)
end

# ===== Protected Area =====

function regulate_protected_area(p, f)
    # Provide resource_factor_fun so incomes scale resource by (1 - f)
    rff(x, pp, t) = (1 - pp.regulation)
    return change(p, regulation=f, resource_factor_fun=rff)
end

function γ_protected_area(val, x, p, t)
    return val .* (1 - p.regulation) .^ -1
end

function yₚ(y::Float64, f_p::Float64, m::Float64; K::Float64=1.0, r::Float64=1.0, xK::Float64=0.0, xr::Float64=0.0)
    if f_p == 0.0
        return K
    end
    r_p = r * (1 + xr)
    K_p = K * (1 + xK)
    k = (1.0 - f_p) / f_p * m
    discriminant = max(0.0, (r_p - k)^2 + 4.0 * r_p * k * y / K_p)
    y_p = ((r_p - k) + sqrt(discriminant)) * K_p / (2.0 * r_p)
    return y_p
end

function rₛ(y, fₚ, m; K::Float64=1.0, r::Float64=1.0, xK::Float64=0.0, xr::Float64=0.0)
    (fₚ / (1 - fₚ) * m * (yₚ(y, fₚ, m; r, K, xK, xr) .- y)) ./ y
end

function μ_protected_area(val, x, p, t)
    return val .* (1 .+ rₛ(x[p.N+1], p.regulation, p.m)) .^ -1
end

# ===== Economic Incentives =====

function regulate_economic_incentive(p, f)
    return change(p, regulation=f)
end

function γ_economic_incentive(val, x, p, t)
    # Placeholder: this function is now defined as a closure in the kit
    return val
end

# ===== Development =====

function regulate_development(p, f)
    return change(p, regulation=f)
end

# ===== Policy composition helper (function-based, no types) =====

"""
    with_policy(s; γ=nothing, μ=nothing, ϕ=nothing, regulate=nothing,
                   income_extra_fun=nothing,
                   extra_state::Int=0, init_extra_state=nothing,
                   label=nothing, policy_meta=NamedTuple())

Return a new scenario based on `s` with any provided policy functions and optional
hooks merged in. All parameters are optional; only non-`nothing` values are applied.

Hooks (optional):
- `income_extra_fun(x, p, t) -> Vector`: additional income component per agent.
- `extra_state::Int`: number of extra ODE states introduced by the policy.
- `init_extra_state(p) -> Vector`: initializer for extra states, length = `extra_state`.
- `label::String` and `policy_meta::NamedTuple`: for display and downstream logic.
"""
function with_policy(s; γ=nothing, μ=nothing, ϕ=nothing, regulate=nothing,
    income_extra_fun=nothing,
    extra_state::Int=0, init_extra_state=nothing,
    label=nothing, policy_meta=NamedTuple(), policy=nothing)

    # Create new policy object
    new_pol_dict = Dict{Symbol,Any}()
    γ !== nothing && (new_pol_dict[:γ] = γ)
    μ !== nothing && (new_pol_dict[:μ] = μ)
    ϕ !== nothing && (new_pol_dict[:ϕ] = ϕ)

    new_pol = (; new_pol_dict...)

    # Append to policies list
    current_policies = hasproperty(s, :policies) ? s.policies : Any[]
    new_policies = vcat(current_policies, [new_pol])

    # Update scenario
    out = (; s..., policies=new_policies)

    # Handle other parameters (merged into scenario for now, but ideally should be in policy struct?)
    # regulate, income_extra_fun, etc. are still scenario-level for now.
    # But if we want multiple policies, regulate needs to be handled carefully.
    # For now, we overwrite regulate as before (last one wins).

    regulate !== nothing && (out = (; out..., regulate))
    income_extra_fun !== nothing && (out = (; out..., income_extra_fun))
    extra_state > 0 && (out = (; out..., extra_state))
    init_extra_state !== nothing && (out = (; out..., init_extra_state))
    label !== nothing && (out = (; out..., label))
    !isempty(propertynames(policy_meta)) && (out = (; out..., policy_meta))
    policy !== nothing && (out = (; out..., policy))

    return out
end

# ===== Policy kit helpers (function-based bundles) =====

"""
    exclusive_use_rights_kit(; selector = (w̃, n) -> (1:n), label="Exclusive Use Rights")

Return a NamedTuple of policy functions for Exclusive Use Rights using the given
`selector` to choose which `n = round(Int, f*N)` agents get rights. The default
selector picks the first n indices; pass a custom selector to choose top/bottom
by some criterion (e.g., w̃).
"""
function exclusive_use_rights_kit(; selector=(w̃, n) -> (1:n), label="Exclusive Use Rights")
    γf(val, x, p, t) = val .+ p.R
    function regulatef(s, f)
        N = s.N
        R = zeros(N)
        n = max(0, min(N, round(Int, f * N)))
        if n > 0
            idx = selector(s.w̃, n)
            R[idx] .= 1.0
        end
        return change(s, R=R, regulation=f)
    end
    (; γ=γf, regulate=regulatef, label, policy="Exclusive Use Rights")
end

"""
    exclusive_use_rights_by_opportunities_kit(; selector = (opportunities, n) -> (1:n),
                                               label = "Exclusive Use Rights (opportunities)")

Variant of Exclusive Use Rights where the selection of beneficiaries is based on
`opportunities` rather than `w̃`. The `selector` function is called with the
opportunities vector and the number of slots `n`, and should return the indices
to receive rights.

If `opportunities` is not present in the scenario, this falls back to `w̃`.
"""
function exclusive_use_rights_by_opportunities_kit(; selector=(opportunities, n) -> (1:n),
    label="Exclusive Use Rights (opportunities)")
    γf(x, p, t) = p.w̃ .+ p.R
    getdata(v) = hasproperty(v, :data) ? v.data : v
    function regulatef(s, f)
        N = s.N
        R = zeros(N)
        n = max(0, min(N, round(Int, f * N)))
        if n > 0
            opp = hasproperty(s, :opportunities) ? getdata(getfield(s, :opportunities)) :
                  (hasproperty(s, :w̃) ? getdata(getfield(s, :w̃)) : zeros(N))
            idx = selector(opp, n)
            R[idx] .= 1.0
        end
        return change(s, R=R, regulation=f)
    end
    (; γ=γf, regulate=regulatef, label, policy="Exclusive Use Rights")
end

"""
    tradable_use_rights_kit(; target=:effort, market_rate=0.05, label="Tradable Use Rights")

Return a NamedTuple policy bundle for tradable use rights. Attaches γ, ϕ,
and regulate; `regulate` also attaches `income_extra_fun` for trade income.
"""
function tradable_use_rights_kit(; target=:effort, market_rate=0.05, buyer_bias::Float64=0.0, label="Tradable Use Rights")
    γf = γ_tradable_use_rights
    ϕf = ϕ_tradable_use_rights
    function regulatef(s, f)
        s2 = change(s, policy_target=target, market_rate=market_rate, buyer_bias=buyer_bias)
        regulate_tradable_use_rights(s2, f)
    end
    (; γ=γf, ϕ=ϕf, regulate=regulatef, label, policy_meta=(; target, market_rate, buyer_bias), policy="Tradable Use Rights")
end

"""
    protected_area_kit(; m=0.3, label="Protected Area")

Return a NamedTuple policy bundle for a Protected Area.
"""
function protected_area_kit(; m=0.3, label="Protected Area")
    γf = γ_protected_area
    μf = μ_protected_area
    function regulatef(p, f)
        regulate_protected_area(change(p, m=m), f)
    end
    (; γ=γf, μ=μf, regulate=regulatef, label, policy_meta=(; m), policy="Protected Area")
end

"""
    economic_incentives_kit(; policy_target=[:γ,:μ], policy_method=:multiplicative, label="Economic Incentives")
"""
function economic_incentives_kit(; policy_target=[:γ, :μ], policy_method=:multiplicative, label="Economic Incentives")
    function γf(val, x, p, t)
        if :γ in vcat(policy_target)
            if policy_method == :additive
                return val .+ p.regulation
            else
                return val .* (1 - p.regulation * (policy_method == :taxation ? -1.0 : 1.0))
            end
        else
            return val
        end
    end

    function μf(val, x, p, t)
        if :μ in vcat(policy_target)
            return val .* (1 - p.regulation * (policy_method == :taxation ? -1.0 : 1.0))
        else
            return val
        end
    end

    function regulatef(p, f)
        change(p, regulation=f, policy_target=policy_target, policy_method=policy_method)
    end
    (; γ=γf, μ=μf, regulate=regulatef, label, policy_meta=(; policy_target, policy_method))
end

"""
    development_kit(; μ_value=0.5, γ_value=0.5, label="Development")
"""
function development_kit(; μ_value=0.5, γ_value=0.5, label="Development")
    function γf(val, x, p, t)
        return val .+ p.regulation * t / 1000 * γ_value
    end

    function μf(val, x, p, t)
        return val .+ p.regulation * 2 / p.N * t / 1000 * μ_value
    end

    function regulatef(p, f)
        change(p, regulation=f, μ_value=μ_value, γ_value=γ_value)
    end
    (; γ=γf, μ=μf, regulate=regulatef, label, policy_meta=(; μ_value, γ_value))
end
