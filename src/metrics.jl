using Statistics

function regulation_scan(p; m=100, kR=0.5, kRent=0.0, kT=1.0, kG=-0.2, kE=0.0, kI=0.0, warmstart::Symbol=:chain)
    r = range(0.0, stop=1.0 - 1.0 / m, length=m)
    RR = zeros(m)
    Rent = zeros(m)
    WR = zeros(m)
    TR = zeros(m)
    ToR = zeros(m)
    GI = zeros(m)
    EH = zeros(m)
    RI = zeros(m)
    Gov = zeros(m)
    oau = zeros(p.N)
    x0 = zeros(p.N + 2)
    x0[p.N+1] = 1.0
    sols = zeros(m, p.N)
    incdist = zeros(m, p.N)
    resources = zeros(m)
    prev_sol = nothing
    if warmstart == :oa_once
        u0, y0_extra... = sim_init(p; from=:oa)
        x0 = vcat(u0, y0_extra...)
    end
    for (j, i) in enumerate(r)
        # Debug logging
        pol = hasproperty(p, :policy) ? p.policy : OpenAccess()
        pol_label = hasproperty(p, :label) ? p.label : string(typeof(pol))

        if warmstart == :chain && prev_sol !== nothing
            # pull previous steady state safely and clamp extra states nonnegative
            u0_prev = prev_sol[1:p.N, end-2]
            y0_prev = prev_sol[p.N+1, end-2]
            if pol isa TradableUseRights
                # Force cold start for TUR to ensure price discovery (demand requires dx > 0)
                sol = sim(p, regulation=i, t_end=1000, u0=fill(1e-5, p.N), y0=1.0, ϕ0=0.0)
            elseif pol isa ProtectedAreaTwoPop
                y2_prev = prev_sol[p.N+2, end-2]
                y2_prev = max(0.0, y2_prev)
                sol = sim(p, regulation=i, t_end=1000, u0=u0_prev, y0=y0_prev, ϕ0=y2_prev)
            else
                sol = sim(p, regulation=i, t_end=1000, u0=u0_prev, y0=y0_prev)
            end
        elseif warmstart == :oa_once
            if pol isa TradableUseRights
                sol = sim(p, regulation=i, t_end=1000, u0=x0[1:p.N], y0=x0[p.N+1], ϕ0=0.0)
            elseif pol isa ProtectedAreaTwoPop
                sol = sim(p, regulation=i, t_end=1000, u0=x0[1:p.N], y0=x0[p.N+1], ϕ0=x0[p.N+1])
            else
                sol = sim(p, regulation=i, t_end=1000, u0=x0[1:p.N], y0=x0[p.N+1])
            end
        else
            sol = sim(p, regulation=i, t_end=1000)
        end
        # Fallback: if integration aborted (retcode not success), re-run cold
        local success = false
        try
            success = (getfield(sol, :retcode) == SciMLBase.ReturnCode.Success)
        catch
            success = false
        end

        if !success
            println("WARNING: Simulation failed/unstable for policy '$pol_label' at f=$i. Retrying cold...")
            sol = sim(p, regulation=i, t_end=1000)
            prev_sol = nothing
        else
            prev_sol = sol
        end
        if j == 1
            oau = sol[1:p.N, end-1]
        end
        inc = incomes(sol.u[end-1], sol.prob.p; t=sol.t[end-1])
        RR[j] = sum(inc.resource)
        Rent[j] = sum(inc.resource_rent)
        WR[j] = sum(inc.wages)
        TR[j] = sum(inc.trade)
        ToR[j] = sum(inc.total)
        GI[j] = inc.gini
        EH[j] = inc.ecological
        regimpact = abs.(oau .- sol[1:p.N, end-1])
        RI[j] = sum(regimpact)
        # Cobb–Douglas style governance on aggregate metrics with safe exponents
        # Aggregates per r
        Rsum = RR[j]
        Tsum = ToR[j]
        Gval = GI[j]
        Eval = EH[j]
        Isum = RI[j]
        # Safe power for nonnegative inputs (avoid complex/NaN from negatives or zeros)
        _sp(x, k) = (max(x, eps())^k)
        Gov[j] = _sp(Rsum, kR) * _sp(Rent[j], kRent) * _sp(Tsum, kT) * _sp(Gval, kG) * _sp(Eval, kE) * _sp(Isum, kI)

        # Sort by w̃ (opportunity cost) for visualization if available
        w_data = hasproperty(p, :w̃) ? (hasproperty(p.w̃, :data) ? p.w̃.data : p.w̃) : nothing
        if w_data !== nothing && length(w_data) == p.N
            id = sortperm(w_data)
            sols[j, :] = sol.u[end-1][id] ./ p.ū[id]
        else
            sols[j, :] = sol.u[end-1][1:p.N] ./ p.ū
        end

        incdist[j, :] = inc.total
        resources[j] = sol.u[end-1][p.N+1]
    end
    oRR = argmax(RR)
    oRent = argmax(Rent)
    oWR = argmax(WR)
    oTR = argmax(TR)
    oToR = argmax(ToR)
    oGI = argmin(GI)
    oEH = argmax(EH)
    oRI = argmax(RI)
    oGov = argmax(Gov)
    return (; RR, Rent, WR, TR, ToR, GI, EH, RI, Gov=Gov ./ 100.0, r, oRR, oRent, oWR, oTR, oToR, oGI, oEH, oRI, oGov, sols, incdist, resources)
end

function _metric_state(p, y)
    pol = hasproperty(p, :policy) ? p.policy : OpenAccess()
    n_extra = (pol isa TradableUseRights || pol isa ProtectedAreaTwoPop) ? 1 : 0
    x = zeros(p.N + 1 + n_extra)
    x[p.N+1] = y
    if pol isa ProtectedAreaTwoPop
        x[p.N+2] = y
    end
    return x
end

function _metric_state(p, y, x)
    state = copy(x)
    length(state) >= p.N + 1 ||
        throw(ArgumentError("metric state must include N actor states and resource density"))
    state[p.N+1] = y
    return state
end

function Γ(y, p; x=nothing, t=0.0)
    state = x === nothing ? _metric_state(p, y) : _metric_state(p, y, x)
    c = p.cost(state, p, t)
    id = sortperm(c)
    f = sum(c[id] .< y) / p.N
end

function Φ(y, p; x=nothing, t=0.0)
    state = x === nothing ? _metric_state(p, y) : _metric_state(p, y, x)
    c = p.cost(state, p, t)
    l = p.limit(state, p, t)
    eligible = findall(<=(1.0), c)
    pressure = 1.0 - y
    pressure <= 0.0 && return 0.0
    isempty(eligible) && return NaN

    id = eligible[sortperm(c[eligible])]
    l_sorted = l[id]
    available_pressure = sum(l_sorted)
    feasibility_tol = 32eps(max(available_pressure, pressure, 1.0))
    if pressure > available_pressure + feasibility_tol
        return NaN
    elseif pressure >= available_pressure - feasibility_tol
        return length(id) / p.N
    end

    cu = cumsum(l_sorted)
    f = sum(cu .< pressure)
    if f == 0
        f = pressure / max(l_sorted[1], eps())
    elseif f < length(id)
        f = f + (pressure - cu[f]) / max(l_sorted[f+1], eps())
    end
    return clamp(f / p.N, 0.0, length(id) / p.N)
end

"""
    tradable_market_diagnostics(sol; index=max(1, length(sol.t) - 2))

Return final quota use, signed quota residual, price, and price derivative for
a `TradableUseRights` simulation. A positive `excess_use` means quota demand
exceeds supply; at a binding converged market, both `excess_use` and
`price_rate` approach zero.
"""
function tradable_market_diagnostics(sol; index=max(1, length(sol.t) - 2))
    p = sol.prob.p
    pol = hasproperty(p, :policy) ? p.policy : OpenAccess()
    pol isa TradableUseRights ||
        throw(ArgumentError("tradable_market_diagnostics requires TradableUseRights"))

    x = sol.u[index]
    y = x[p.N+1]
    quota = sum(p.R)
    quota_use = pol.target == :yield ? y * sum(x[1:p.N]) : sum(x[1:p.N])
    dx = zeros(eltype(x), length(x))
    dxdt(dx, x, p, sol.t[index])
    return (
        target=pol.target,
        quota=quota,
        quota_use=quota_use,
        excess_use=quota_use - quota,
        quota_balance_error=abs(quota_use - quota),
        quota_violation=max(quota_use - quota, 0.0),
        price=x[p.N+2],
        price_rate=dx[p.N+2],
        complementarity_error=abs(x[p.N+2] * (quota_use - quota)),
    )
end

"""
    incomes(x, p; summarize=false, dimensional=false, t=0.0)

Decompose actor income in the common baseline numeraire. `resource_revenue`
is retained harvest revenue; `resource_rent` subtracts forgone outside earnings
(`opportunity_cost`). Rights transfers and state receipts are separate.
Legacy `resource`, `wages`, `wages_0`, and `trade` fields remain available.
Generic economic transformations describe changed outside returns/endowments
unless explicit income hooks specify a different dimensional mechanism.
"""
function incomes(x, p; summarize=false, dimensional::Bool=false, t=0.0)
    # unpack state and parameters
    y = x[p.N+1]
    u_model = x[1:p.N]
    pol = hasproperty(p, :policy) ? p.policy : OpenAccess()

    # The reduced protected-area model stores ecological-equivalent use so
    # that its one-resource equilibrium matches the explicit two-patch model.
    # Income, however, is earned from physical use and foregone from the
    # unchanged physical endowment.
    u = if pol isa ProtectedArea
        scale = protected_pressure_scale(y, p.regulation, pol.m)
        scale <= eps() ? zeros(p.N) : clamp.(u_model ./ scale, 0.0, p.ū)
    else
        u_model
    end

    # Retained harvest revenue, before subtracting the opportunity cost.
    rf = hasproperty(p, :resource_factor_fun) ? p.resource_factor_fun(x, p, t) : 1.0
    resource_factor = rf isa Number ? fill(rf, p.N) : rf
    resource_nd = u .* y .* resource_factor

    # wages based on μ and γ. For policies that introduce a market price or
    # rescale incentives (TUR/EUR/PA), use the baseline w̃ for wage accounting
    # and keep market-related revenue in the extra (trade) component.
    μ = pol isa ProtectedArea ?
        (hasproperty(p.ū, :data) ? p.ū.data : p.ū) :
        p.limit(x, p, t)

    use_baseline_cost = (pol isa TradableUseRights) ||
                        (pol isa ExclusiveUseRights) ||
                        (pol isa ProtectedArea) ||
                        (pol isa ProtectedAreaTwoPop)

    # A decision wedge (for example a royalty) need not change outside earnings.
    γw = if hasproperty(p, :income_cost_fun)
        p.income_cost_fun(x, p, t)
    elseif use_baseline_cost && hasproperty(p, :w̃)
        hasproperty(p.w̃, :data) ? p.w̃.data : p.w̃
    else
        p.cost(x, p, t)
    end
    wages_nd = (μ .- u) .* γw
    wages_0_nd = μ .* γw

    # optional additional income component provided by policy
    extra_nd = hasproperty(p, :income_extra_fun) ? p.income_extra_fun(x, p, t) : zeros(p.N)
    state_nd = hasproperty(p, :income_state_fun) ? p.income_state_fun(x, p, t) : zeros(p.N)

    total_nd = resource_nd .+ wages_nd .+ extra_nd
    g = gini(total_nd)
    ecological = y

    if dimensional
        scale = p.rpk
        resource = resource_nd .* scale
        wages = wages_nd .* scale
        wages_0 = wages_0_nd .* scale
        extra = extra_nd .* scale
        total = total_nd .* scale
    else
        resource, wages, wages_0, extra, total = resource_nd, wages_nd, wages_0_nd, extra_nd, total_nd
    end

    state_revenue = state_nd .* (dimensional ? p.rpk : 1.0)
    opportunity_cost = u .* γw .* (dimensional ? p.rpk : 1.0)
    resource_rent = resource .- opportunity_cost
    rights_transfer = pol isa TradableUseRights ? extra : zeros(p.N)
    other_income = pol isa TradableUseRights ? zeros(p.N) : extra
    out = (; resource, wages, extra, trade=extra, total, gini=g, ecological, wages_0,
        resource_revenue=resource, gross_resource_revenue=resource .+ state_revenue,
        resource_rent, opportunity_cost, outside_income=wages, outside_income_0=wages_0,
        rights_transfer, other_income, state_revenue,
        net_resource_rent=resource_rent .+ rights_transfer)
    return summarize ? merge(out, (; g=g, ecological=ecological)) : out
end

incomes(sol::ODESolution; t=sol.t[end], kwargs...) = incomes(sol.u[end], sol.prob.p; t, kwargs...)

function gini(x)
    sum([abs(x[i] - x[j]) for i in 1:length(x), j in 1:length(x)]) / (2 * length(x) * sum(x))
end
