# Centralized Policy Implementation
# Policies as Types: Using Julia's multiple dispatch for extensibility and simplicity.

using OrdinaryDiffEq
using DiffEqCallbacks: TerminateSteadyState
using Random

export AbstractPolicy
export OpenAccess, TradableUseRights, ExclusiveUseRights, ProtectedArea, ProtectedAreaTwoPop, EconomicIncentives, Development
export cost, limit, dynamics, regulate

# =========================================================================================
# Abstract Policy Type
# =========================================================================================

abstract type AbstractPolicy end

# =========================================================================================
# Concrete Policy Structs
# =========================================================================================

struct OpenAccess <: AbstractPolicy end

struct TradableUseRights <: AbstractPolicy
    target::Symbol      # :effort or :yield
    market_rate::Float64
    buyer_bias::Float64
    historical_use_rights::Bool
end

struct ExclusiveUseRights <: AbstractPolicy
    selector::Symbol # :top, :bottom, :random
    reverse::Bool # Legacy parameter
end

struct ProtectedArea <: AbstractPolicy
    m::Float64 # Mobility
end

struct ProtectedAreaTwoPop <: AbstractPolicy
    m::Float64 # Migration
end

struct EconomicIncentives <: AbstractPolicy
    target::Vector{Symbol} # [:cost] or [:limit]
    method::Symbol # :taxation, :additive, :multiplicative
end

struct Development <: AbstractPolicy
    μ_value::Float64
    γ_value::Float64
end


# =========================================================================================
# Dispatchers & Fallbacks
# =========================================================================================

# --- Dispatchers (Unpack policy from scenario) ---
cost(val, x, p, t) = cost(val, x, p, t, p.policy)
limit(val, x, p, t) = limit(val, x, p, t, p.policy)
dynamics(dx, x, p, t) = dynamics(dx, x, p, t, p.policy)
regulate(s, f) = regulate(s, f, s.policy)

# --- Default Fallbacks (Open Access behavior) ---
cost(val, x, p, t, ::AbstractPolicy) = val
limit(val, x, p, t, ::AbstractPolicy) = val
dynamics(dx, x, p, t, ::AbstractPolicy) = nothing

"""
    regulate(s, f, policy)

Apply regulation level `f` to scenario `s` for the given policy.
Returns a new scenario with updated parameters.
"""
function regulate(s, f, pol::AbstractPolicy)
    return change(s, regulation=f)
end


# =========================================================================================
# Policy Implementations
# =========================================================================================

# ----- Tradable Use Rights (TUR) -----

function regulate(s, f, pol::TradableUseRights)
    # Default allocation: equal shares of allowed effort or yield

    R = fill((1 - Float64(f)) / s.N, s.N)


    if pol.historical_use_rights
        # Historical users share the quota equally; realized open-access use
        # determines eligibility, not the size of each initial endowment.
        s_oa = change(s, policy=OpenAccess())
        y0 = 1.0
        u0 = fill(0.0, s.N)
        oaprob = ODEProblem(dxdt, [u0; y0], (0.0, 1000.0), s_oa)
        oasol = _solve_primary(oaprob)
        historical_users = oasol[1:s.N, end-1] .> 0.0
        n_historical = count(historical_users)
        if n_historical > 0
            R = historical_users .* ((1 - f) / n_historical)
        end
    end

    # Attach income extra function for trade revenue
    function _tur_income_extra(x, p, t)
        u = x[1:p.N]
        p.regulation == 0 && return zeros(eltype(u), p.N)
        y = x[p.N+1]
        # p.policy is now the struct
        target = p.policy.target
        if target == :yield
            (p.R .- (u .* y)) .* x[p.N+2]
        else
            (p.R .- u) .* x[p.N+2]
        end
    end

    # Calculate Buyer Bias Weights
    bias = pol.buyer_bias
    tur_weights = ones(s.N)
    if bias != 0.0 && hasproperty(s, :opportunities)
        opp = getfield(s, :opportunities)
        oppv = hasproperty(opp, :data) ? opp.data : opp
        if length(oppv) == s.N
            omin = minimum(oppv)
            omax = maximum(oppv)
            rng = omax - omin
            if rng > 0
                norm = (oppv .- omin) ./ rng
                s_scaled = 2 .* (norm .- 0.5)
                tur_weights .= clamp.(1 .+ bias .* s_scaled, 0.001, Inf)
            end
        end
    end

    return change(s, R=R, regulation=f, income_extra_fun=_tur_income_extra)
end

function cost(val, x, p, t, pol::TradableUseRights)
    p.regulation == 0 && return val
    price = length(x) >= p.N + 2 ? x[p.N+2] : 0.0
    price_wedge = pol.target == :yield ? x[p.N+1] * price : price
    return val .+ price_wedge
end

function dynamics(dx, x, p, t, pol::TradableUseRights)
    if p.regulation == 0
        dx[p.N+2] = 0.0
        return nothing
    end

    target = pol.target
    market_rate = pol.market_rate

    use = target == :yield ? x[1:p.N] .* x[p.N+1] : x[1:p.N]
    quota = sum(p.R)
    excess_use = sum(use) - quota
    raw_price_rate = market_rate * excess_use
    price = x[p.N+2]
    dx[p.N+2] = price <= MARKET_PROJECTION_TOL && raw_price_rate < 0.0 ?
                0.0 : raw_price_rate
end

# ----- Exclusive Use Rights (EUR) -----

function regulate(s, f, pol::ExclusiveUseRights)
    N = s.N
    R = zeros(N)
    n = max(0, min(N, round(Int, f * N)))

    if n > 0
        # Determine selection strategy
        selector = pol.selector

        # The manuscript policy selects actors by exit threshold. Outside
        # opportunities can help construct thresholds, but are not themselves
        # the selection variable.
        data = hasproperty(s, :w̃) ?
               (hasproperty(s.w̃, :data) ? s.w̃.data : s.w̃) :
               zeros(N)

        idx = Int[]
        if selector == :top
            idx = sortperm(data, rev=true)[1:n]
        elseif selector == :bottom
            idx = sortperm(data)[1:n]
        elseif selector == :random
            idx = shuffle(1:N)[1:n]
        end

        R[idx] .= 1.0
    end
    return change(s, R=R, regulation=f)
end

function cost(val, x, p, t, pol::ExclusiveUseRights)
    # Add R to cost (R=1 means excluded/high cost)
    return val .+ p.R
end


# ----- Protected Area (PA) -----

function regulate(p, f, pol::ProtectedArea)
    # Provide resource_factor_fun so incomes scale resource by (1 - f)
    rff(x, pp, t) = (1 - pp.regulation)
    return change(p, regulation=f, resource_factor_fun=rff)
end

function cost(val, x, p, t, pol::ProtectedArea)
    return val .* (1 - p.regulation) .^ -1
end

function yₚ(y::Float64, f_p::Float64, m::Float64; K::Float64=1.0, r::Float64=1.0, xK::Float64=0.0, xr::Float64=0.0)
    if f_p == 0.0
        return K
    end
    r_p = r * (1 + xr)
    K_p = K * (1 + xK)
    # At quasi-steady state, the protected-patch equation is
    # y_p(1-y_p) - m(y_p-y) = 0. The protected fraction scales the
    # reciprocal flux in the exploited patch, not this local balance.
    k = m
    discriminant = max(0.0, (r_p - k)^2 + 4.0 * r_p * k * y / K_p)
    y_p = ((r_p - k) + sqrt(discriminant)) * K_p / (2.0 * r_p)
    return y_p
end

function rₛ(y, fₚ, m; K::Float64=1.0, r::Float64=1.0, xK::Float64=0.0, xr::Float64=0.0)
    (fₚ / (1 - fₚ) * m * (yₚ(y, fₚ, m; r, K, xK, xr) .- y)) ./ max.(y, 1e-6)
end

"""
    protected_pressure_scale(y, f_p, m)

Convert physical use in the explicit protected/exploited-patch equilibrium to
ecological-equivalent use in the one-resource geometry.  If `h(y)` is the
spillover contribution per unit exploited stock, the explicit equilibrium is
`sum(u) = 1 - y + h(y)`.  Multiplication by this factor makes the same physical
use balance the ordinary one-resource target `1 - y` exactly.
"""
function protected_pressure_scale(y, f_p, m;
        K::Float64=1.0, r::Float64=1.0,
        xK::Float64=0.0, xr::Float64=0.0)
    (f_p == 0.0 || m == 0.0) && return 1.0

    # Evaluate the removable 0/0 endpoint just inside the normalized domain.
    # This keeps the state limiter finite when simulations initialize at y=1.
    y_eval = clamp(Float64(y), 0.0, 1.0 - 1e-8)
    replacement = 1.0 - y_eval
    h = rₛ(y_eval, f_p, m; K, r, xK, xr)
    return clamp(replacement / max(replacement + h, eps()), 0.0, 1.0)
end

function limit(val, x, p, t, pol::ProtectedArea)
    scale = protected_pressure_scale(x[p.N+1], p.regulation, pol.m)
    return val .* scale
end

# ----- Protected Area Two Populations -----

function regulate(p, f, pol::ProtectedAreaTwoPop)
    rff(x, pp, t) = (1 - pp.regulation)
    return change(p, regulation=f, resource_factor_fun=rff)
end

function cost(val, x, p, t, pol::ProtectedAreaTwoPop)
    return val .* (1 - p.regulation) .^ -1
end

function dynamics(dx, x, p, t, pol::ProtectedAreaTwoPop)
    y_u = x[p.N+1]
    y_p = x[p.N+2]
    migration = pol.m * (y_p - y_u)
    dx[p.N+1] += p.regulation / (1.0 - p.regulation) * migration
    dx[p.N+2] = y_p * (1.0 - y_p) - migration
end

function limit(val, x, p, t, pol::ProtectedAreaTwoPop)
    # Spillover is already present in the explicit resource dynamics, so the
    # physical actor endowment must not be transformed a second time.
    return val
end

# ----- Economic Incentives -----

function regulate(p, f, pol::EconomicIncentives)
    return change(p, regulation=f)
end

function cost(val, x, p, t, pol::EconomicIncentives)
    if :incentives in pol.target || :cost in pol.target || :γ in pol.target
        if pol.method == :additive
            return val .+ p.regulation
        else
            return val .* (1 - p.regulation * (pol.method == :taxation ? -1.0 : 1.0))
        end
    end
    return val
end

function limit(val, x, p, t, pol::EconomicIncentives)
    if :impact in pol.target || :limit in pol.target || :μ in pol.target
        return val .* (1 - p.regulation * (pol.method == :taxation ? -1.0 : 1.0))
    end
    return val
end

# ----- Development -----

function regulate(p, f, pol::Development)
    return change(p, regulation=f)
end

function cost(val, x, p, t, pol::Development)
    return val .+ p.regulation * t / 1000 * pol.γ_value
end

function limit(val, x, p, t, pol::Development)
    return val .+ p.regulation * 2 / p.N * t / 1000 * pol.μ_value
end
