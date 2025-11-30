using OrdinaryDiffEq
using DiffEqCallbacks: TerminateSteadyState

"""
    sim_init(p; from::Symbol = :zeros, t_end=1000.0)

Return a tuple of initial values `(u0, y0, extra...)` matching the scenario `p`.
`from = :zeros` produces zeros; `from = :oa` solves Open Access once and
returns its steady state as a warm start (u*, y*, extra set to defaults).
"""
function sim_init(p; from::Symbol=:zeros, t_end=1000.0)
    N = p.N
    pol = hasproperty(p, :policy) ? p.policy : "Open Access"

    if from == :zeros
        if pol == "Tradable Use Rights"
            return (zeros(N), 1.0, 0.0)
        elseif pol == "Protected Area Two Pop"
            return (zeros(N), 1.0, 1.0)
        else
            return (zeros(N), 1.0)
        end
    elseif from == :oa
        # OA warm start: solve with f=0.0 and reuse u*, y*
        u0, y0_extra... = sim_init(p; from=:zeros)
        initVals = vcat(u0, y0_extra...)
        oa = p.regulate(p, 0.0)
        prob = ODEProblem(dxdt, initVals, (0.0, t_end), oa)
        sol = solve(prob, SSPRK432(; stage_limiter!), callback=TerminateSteadyState(1e-6, 1e-4))
        # Copy back u*, y* and keep extra states at defaults
        if pol == "Tradable Use Rights"
            return (sol[1:N, end-2], sol[N+1, end-2], 0.0)
        elseif pol == "Protected Area Two Pop"
            return (sol[1:N, end-2], sol[N+1, end-2], sol[N+1, end-2])
        else
            return (sol[1:N, end-2], sol[N+1, end-2])
        end
    else
        error("Unsupported sim_init from=$(from)")
    end
end

function dxdt(dx, x, p, t)
    N = p.N
    # Effort dynamics: proportional to Profit (Revenue - Cost)
    dx[1:N] = p.α .* (x[N+1] .- p.cost(x, p, t))
    # Resource dynamics: Logistic Growth - Harvest
    dx[N+1] = x[N+1] * ((1 - x[N+1]) - sum(x[1:N]))
    # Policy dynamics (e.g. market price)
    p.dynamics(dx, x, p, t)
end

function stage_limiter!(x, integrator, p, t)
    # Limit effort between 0 and capacity/limit
    limit_val = p.limit(x, p, t)
    x[1:p.N] .= ifelse.(x[1:p.N] .< 0.0, 0.0,
        ifelse.(x[1:p.N] .> limit_val, limit_val, x[1:p.N]))
    for j in p.N+1:length(x)
        x[j] = max(0.0, x[j])
    end
end

function sim(s; u0=zeros(s.N), y0=1.0, ϕ0=0.0, regulation=0.0, start_from_OA=false, t_end=1000.0)
    sample!(s; force=false)
    tspan = (0.0, t_end)
    p = s.regulate(s, regulation)
    pol = hasproperty(p, :policy) ? p.policy : "Open Access"

    if pol == "Tradable Use Rights"
        initVals = [u0; y0; ϕ0]
    elseif pol == "Protected Area Two Pop"
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
    # try primary algorithm with limiter; on failure, try fallbacks
    function _try_solve(prob)
        # 1) SSPRK with limiter
        try
            sol = solve(prob, SSPRK432(; stage_limiter!), callback=TerminateSteadyState(1e-6, 1e-4))
            return sol
        catch
        end
        # 2) Stiff fallback
        try
            sol = solve(prob, Rosenbrock23(), callback=TerminateSteadyState(1e-6, 1e-4))
            return sol
        catch
        end
        # 3) Non-stiff fallback
        return solve(prob, Tsit5(), callback=TerminateSteadyState(1e-6, 1e-4))
    end
    sol = _try_solve(prob)
    return sol
end
