# Centralized Policy Implementation
# Replaces the complex "Kit" system with straightforward dispatch.

using OrdinaryDiffEq
using DiffEqCallbacks: TerminateSteadyState
using Random

export cost, limit, dynamics, regulate

# =========================================================================================
# Dispatch Functions (Called by Master Functions in scenarios.jl)
# =========================================================================================

function cost(val, x, p, t)
    pol = p.policy
    if pol == "Tradable Use Rights"
        return cost_tur(val, x, p, t)
    elseif pol == "Exclusive Use Rights"
        return cost_eur(val, x, p, t)
    elseif pol == "Protected Area"
        return cost_pa(val, x, p, t)
    elseif pol == "Protected Area Two Pop"
        return val # PA Two Pop only affects dynamics and limit
    elseif pol == "Economic Incentives"
        return cost_ei(val, x, p, t)
    elseif pol == "Development"
        return cost_dev(val, x, p, t)
    end
    return val
end

function limit(val, x, p, t)
    pol = p.policy
    if pol == "Protected Area"
        return limit_pa(val, x, p, t)
    elseif pol == "Protected Area Two Pop"
        return limit_pa_two_pop(val, x, p, t)
    elseif pol == "Economic Incentives"
        return limit_ei(val, x, p, t)
    elseif pol == "Development"
        return limit_dev(val, x, p, t)
    end
    return val
end

function dynamics(dx, x, p, t)
    pol = p.policy
    if pol == "Tradable Use Rights"
        dynamics_tur(dx, x, p, t)
    elseif pol == "Protected Area Two Pop"
        dynamics_pa_two_pop(dx, x, p, t)
    end
end

# =========================================================================================
# Regulation Logic (Called by sim() to set up the scenario before solving)
# =========================================================================================

function regulate(s, f)
    pol = s.policy
    if pol == "Tradable Use Rights"
        return regulate_tur(s, f)
    elseif pol == "Exclusive Use Rights"
        return regulate_eur(s, f)
    elseif pol == "Protected Area"
        return regulate_pa(s, f)
    elseif pol == "Protected Area Two Pop"
        return regulate_pa_two_pop(s, f)
    elseif pol == "Economic Incentives"
        return regulate_ei(s, f)
    elseif pol == "Development"
        return regulate_dev(s, f)
    end
    return change(s, regulation=f)
end

# =========================================================================================
# Policy Implementations
# =========================================================================================

# ----- Tradable Use Rights (TUR) -----

function regulate_tur(s, f)
    # Defaults
    target = hasproperty(s, :policy_target) ? s.policy_target : :effort

    # Default allocation: equal shares of allowed effort or yield
    R = fill(f == 0 ? 1.0 : (1 - Float64(f)) / s.N, s.N)

    if haskey(s, :historical_use_rights) && s.historical_use_rights
        # Solve OA once to estimate historical baselines
        # Create a temporary OA scenario
        s_oa = change(s, policy="Open Access")
        u0 = zeros(s.N)
        y0 = 1.0
        oaprob = ODEProblem(dxdt, [u0; y0], (0.0, 1000.0), s_oa)
        oasol = solve(oaprob, SSPRK432(; stage_limiter!), callback=TerminateSteadyState(1e-6, 1e-4))

        if target == :yield
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
        target = hasproperty(p, :policy_target) ? p.policy_target : :effort
        if target == :yield
            (p.R .- (u .* y)) .* x[p.N+2]
        else
            (p.R .- u) .* x[p.N+2]
        end
    end

    return change(s, R=R, regulation=f, income_extra_fun=_tur_income_extra)
end

function cost_tur(val, x, p, t)
    # Cost = w + Price
    return val .+ x[end]
end

function dynamics_tur(dx, x, p, t)
    target = hasproperty(p, :policy_target) ? p.policy_target : :effort
    market_rate = hasproperty(p, :market_rate) ? p.market_rate : 0.05

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
    bias = hasproperty(p, :buyer_bias) ? Float64(getfield(p, :buyer_bias)) : 0.0
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

function regulate_eur(s, f)
    N = s.N
    R = zeros(N)
    n = max(0, min(N, round(Int, f * N)))

    if n > 0
        # Determine selection strategy from policy_name or extra field
        # Default to "top" if not specified
        # We can use s.selector if provided, or infer from policy variant name

        # Get data to sort by (opportunities or w̃)
        data = hasproperty(s, :opportunities) ? (hasproperty(s.opportunities, :data) ? s.opportunities.data : s.opportunities) :
               (hasproperty(s, :w̃) ? (hasproperty(s.w̃, :data) ? s.w̃.data : s.w̃) : zeros(N))

        selector = hasproperty(s, :selector) ? s.selector : :top

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

function cost_eur(val, x, p, t)
    # Add R to cost (R=1 means excluded/high cost)
    return val .+ p.R
end

# ----- Protected Area (PA) -----

function regulate_pa(p, f)
    # Provide resource_factor_fun so incomes scale resource by (1 - f)
    rff(x, pp, t) = (1 - pp.regulation)
    return change(p, regulation=f, resource_factor_fun=rff)
end

function cost_pa(val, x, p, t)
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

function limit_pa(val, x, p, t)
    m = hasproperty(p, :m) ? p.m : 0.3
    return val .* (1 .+ rₛ(x[p.N+1], p.regulation, m)) .^ -1
end

# ----- Protected Area Two Populations -----

function regulate_pa_two_pop(p, f)
    m = hasproperty(p, :m) ? p.m : 0.3
    return change(p, regulation=f, m=m)
end

function dynamics_pa_two_pop(dx, x, p, t)
    mx = x[p.N+2] - x[p.N+1]
    dx[p.N+2] = (1.0 - x[p.N+2]) * dx[p.N+2] - (1.0 - p.regulation) / p.regulation * p.m * mx
    dx[p.N+1] += p.regulation / (1.0 - p.regulation) * p.m * mx
end

function limit_pa_two_pop(val, x, p, t)
    y_u = x[p.N+1]
    y_p = x[p.N+2]
    # Regularized division by y_u
    r_s_local = ((1.0 - p.regulation) / p.regulation) * p.m * (y_p - y_u) / max(y_u, 1e-6)
    return val .* (1 .+ r_s_local) .^ (-1)
end

# ----- Economic Incentives -----

function regulate_ei(p, f)
    return change(p, regulation=f)
end

function cost_ei(val, x, p, t)
    target = hasproperty(p, :policy_target) ? p.policy_target : [:cost, :limit]
    method = hasproperty(p, :policy_method) ? p.policy_method : :multiplicative

    if :cost in vcat(target) || :γ in vcat(target) # Support old symbol too
        if method == :additive
            return val .+ p.regulation
        else
            return val .* (1 - p.regulation * (method == :taxation ? -1.0 : 1.0))
        end
    end
    return val
end

function limit_ei(val, x, p, t)
    target = hasproperty(p, :policy_target) ? p.policy_target : [:cost, :limit]
    method = hasproperty(p, :policy_method) ? p.policy_method : :multiplicative

    if :limit in vcat(target) || :μ in vcat(target) # Support old symbol too
        return val .* (1 - p.regulation * (method == :taxation ? -1.0 : 1.0))
    end
    return val
end

# ----- Development -----

function regulate_dev(p, f)
    μ_value = hasproperty(p, :μ_value) ? p.μ_value : 0.5
    γ_value = hasproperty(p, :γ_value) ? p.γ_value : 0.5
    return change(p, regulation=f, μ_value=μ_value, γ_value=γ_value)
end

function cost_dev(val, x, p, t)
    return val .+ p.regulation * t / 1000 * p.γ_value
end

function limit_dev(val, x, p, t)
    return val .+ p.regulation * 2 / p.N * t / 1000 * p.μ_value
end
