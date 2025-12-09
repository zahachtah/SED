using Statistics

function regulation_scan(p; m=100, kR=0.5, kT=1.0, kG=-0.2, kE=0.0, kI=0.0, warmstart::Symbol=:chain)
    r = range(0.0, stop=1.0 - 1.0 / m, length=m)
    RR = zeros(m)
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
        inc = incomes(sol.u[end-1], sol.prob.p)
        RR[j] = sum(inc.resource)
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
        Gov[j] = _sp(Rsum, kR) * _sp(Tsum, kT) * _sp(Gval, kG) * _sp(Eval, kE) * _sp(Isum, kI)

        # Sort by w̃ (opportunity cost) for visualization if available
        w_data = hasproperty(p, :w̃) ? (hasproperty(p.w̃, :data) ? p.w̃.data : p.w̃) : nothing
        if w_data !== nothing && length(w_data) == p.N
            id = sortperm(w_data)
            sols[j, :] = sol.u[end-1][id] ./ p.ū[id]
        else
            sols[j, :] = sol.u[end-1][1:p.N] ./ p.ū
        end

        incdist[j, :] = inc.total
        resources[j] = sol.u[end-1][p.N+1]
    end
    oRR = argmax(RR)
    oWR = argmax(WR)
    oTR = argmax(TR)
    oToR = argmax(ToR)
    oGI = argmin(GI)
    oEH = argmax(EH)
    oRI = argmax(EH)
    oGov = argmax(Gov)
    return (; RR, WR, TR, ToR, GI, EH, RI, Gov=Gov ./ 100.0, r, oRR, oWR, oTR, oToR, oGI, oEH, oRI, oGov, sols, incdist, resources)
end

function Γ(y, p; x=zeros(p.N + 1), t=0.0)
    x[p.N+1] = y
    c = p.cost(x, p, t)
    id = sortperm(c)
    f = sum(c[id] .< y) / p.N
end

function Φ(y, p; t=0.0)
    x = zeros(p.N + 1)
    x[end] = y
    c = p.cost(x, p, t)
    id = sortperm(c)
    l = p.limit(x, p, t)
    cu = cumsum(l[id])
    f = sum(cu .< (1.0 - y))
    if f == 0
        f = (1.0 - y) / l[id[1]]
    elseif f < p.N
        f = f + ((1 - y) - cu[f]) / l[id[f+1]]
    end
    return f / p.N
end

function incomes(x, p; summarize=false, dimensional::Bool=false)
    # unpack state and parameters
    y = x[p.N+1]
    u = x[1:p.N]

    # resource income with optional policy-provided factor
    rf = hasproperty(p, :resource_factor_fun) ? p.resource_factor_fun(x, p, 0.0) : 1.0
    resource_factor = rf isa Number ? fill(rf, p.N) : rf
    resource_nd = u .* y .* resource_factor

    # wages based on μ and γ. For policies that introduce a market price or
    # rescale incentives (TUR/EUR/PA), use the baseline w̃ for wage accounting
    # and keep market-related revenue in the extra (trade) component.
    μ = p.limit(x, p, 0.0)
    pol = hasproperty(p, :policy) ? p.policy : OpenAccess()

    use_baseline_cost = (pol isa TradableUseRights) ||
                        (pol isa ExclusiveUseRights) ||
                        (pol isa ProtectedArea)

    γw = if use_baseline_cost && hasproperty(p, :w̃)
        hasproperty(p.w̃, :data) ? p.w̃.data : p.w̃
    else
        p.cost(x, p, 0.0)
    end
    wages_nd = (μ .- u) .* γw
    wages_0_nd = μ .* γw

    # optional additional income component provided by policy
    extra_nd = hasproperty(p, :income_extra_fun) ? p.income_extra_fun(x, p, 0.0) : zeros(p.N)

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

    out = (; resource, wages, extra, trade=extra, total, gini=g, ecological, wages_0)
    return summarize ? merge(out, (; g=g, ecological=ecological)) : out
end

incomes(sol::ODESolution) = incomes(sol.u[end], sol.prob.p)

function gini(x)
    sum([abs(x[i] - x[j]) for i in 1:length(x), j in 1:length(x)]) / (2 * length(x) * sum(x))
end
