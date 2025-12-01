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
    R = fill(f == 0 ? 1.0 : (1 - Float64(f)) / s.N, s.N)

    if pol.historical_use_rights
        # Solve OA once to estimate historical baselines
        # Create a temporary OA scenario
        s_oa = change(s, policy=OpenAccess())
        u0 = fill(0.1, s.N) # Ensure non-zero start
        y0 = 1.0
        oaprob = ODEProblem(dxdt, [u0; y0], (0.0, 1000.0), s_oa)
        oasol = solve(oaprob, SSPRK432(; stage_limiter!), callback=TerminateSteadyState(1e-6, 1e-4))

        if pol.target == :yield
            hist_u = oasol[1:s.N, end-1]
            hist_y = oasol[s.N+1, end-1]
            hist_yield = hist_u .* hist_y
            total_hist_yield = sum(hist_yield)
            if total_hist_yield > 0
                R = hist_yield .* (1 - f) ./ total_hist_yield
            end
        else
            hur = oasol[1:s.N, end-1]
            denom = sum(hur)
            if denom > 0
                R = hur .* (1 - f) ./ denom
            end
        end
    end

    # Attach income extra function for trade revenue
    function _tur_income_extra(x, p, t)
        u = x[1:p.N]
        y = x[p.N+1]
        # p.policy is now the struct
        target = p.policy.target
        if target == :yield
            (p.R .- (u .* y)) .* x[p.N+2]
        else
            (p.R .- u) .* x[p.N+2]
        end
    end

    return change(s, R=R, regulation=f, income_extra_fun=_tur_income_extra)
end

function cost(val, x, p, t, pol::TradableUseRights)
    # Cost = w + Price
    return val .+ x[end]
end

function dynamics(dx, x, p, t, pol::TradableUseRights)
    target = pol.target
    market_rate = pol.market_rate

    # Supply: Aggregate clamping (Legacy/Stable logic)
    supply = if target == :yield
        clamp(sum(p.R .- (x[1:p.N] .* x[p.N+1])), 0.0, Inf)
    else
        max(0.0, sum(p.R .- x[1:p.N]))
    end

    # Demand
    id = findall((dx[1:p.N] .> 0.0))
    ind_demand = if target == :yield
        max_extra_yield = (p.ū[id] .- x[id]) .* x[p.N+1]
        desired_extra_yield = dx[id] .* x[p.N+1]
        min.(max_extra_yield, desired_extra_yield)
    else
        min.(p.ū[id] - x[id], dx[id])
    end

    # Buyer Bias
    bias = pol.buyer_bias
    if bias != 0.0 && hasproperty(p, :opportunities)
        opp = getfield(p, :opportunities)
        oppv = hasproperty(opp, :data) ? opp.data : opp
        if length(oppv) == p.N
            omin = minimum(oppv)
            omax = maximum(oppv)
            rng = omax - omin
            if rng > 0
                norm = (oppv .- omin) ./ rng
                s = 2 .* (norm .- 0.5)
                wfull = clamp.(1 .+ bias .* s, 0.001, Inf)
                ind_demand = ind_demand .* wfull[id]
            end
        end
    end

    demand = sum(ind_demand)

    # Price Dynamics
    dx[p.N+2] = market_rate * (demand - supply)

    # Rationing if demand exceeds supply
    if demand > supply && demand > 0
        if target == :yield
            y = max(eps(), x[p.N+1])
            dx[id] .= (supply .* ind_demand ./ demand) ./ y
        else
            dx[id] .= supply .* ind_demand ./ demand
        end
    end
end

# ----- Exclusive Use Rights (EUR) -----

function regulate(s, f, pol::ExclusiveUseRights)
    N = s.N
    R = zeros(N)
    n = max(0, min(N, round(Int, f * N)))

    if n > 0
        # Determine selection strategy
        selector = pol.selector

        # Get data to sort by (opportunities or w̃)
        data = hasproperty(s, :opportunities) ? (hasproperty(s.opportunities, :data) ? s.opportunities.data : s.opportunities) :
               (hasproperty(s, :w̃) ? (hasproperty(s.w̃, :data) ? s.w̃.data : s.w̃) : zeros(N))

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
    k = (1.0 - f_p) / f_p * m
    discriminant = max(0.0, (r_p - k)^2 + 4.0 * r_p * k * y / K_p)
    y_p = ((r_p - k) + sqrt(discriminant)) * K_p / (2.0 * r_p)
    return y_p
end

function rₛ(y, fₚ, m; K::Float64=1.0, r::Float64=1.0, xK::Float64=0.0, xr::Float64=0.0)
    (fₚ / (1 - fₚ) * m * (yₚ(y, fₚ, m; r, K, xK, xr) .- y)) ./ max.(y, 1e-6)
end

function limit(val, x, p, t, pol::ProtectedArea)
    return val .* (1 .+ rₛ(x[p.N+1], p.regulation, pol.m)) .^ -1
end

# ----- Protected Area Two Populations -----

function regulate(p, f, pol::ProtectedAreaTwoPop)
    return change(p, regulation=f)
end

function dynamics(dx, x, p, t, pol::ProtectedAreaTwoPop)
    mx = x[p.N+2] - x[p.N+1]
    dx[p.N+2] = (1.0 - x[p.N+2]) * dx[p.N+2] - (1.0 - p.regulation) / p.regulation * pol.m * mx
    dx[p.N+1] += p.regulation / (1.0 - p.regulation) * pol.m * mx
end

function limit(val, x, p, t, pol::ProtectedAreaTwoPop)
    y_u = x[p.N+1]
    y_p = x[p.N+2]
    # Regularized division by y_u
    r_s_local = ((1.0 - p.regulation) / p.regulation) * pol.m * (y_p - y_u) / max(y_u, 1e-6)
    return val .* (1 .+ r_s_local) .^ (-1)
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
