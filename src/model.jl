using OrdinaryDiffEq
using DiffEqCallbacks: TerminateSteadyState

const DEFAULT_SOLVER_ABSTOL = 1e-8
const DEFAULT_SOLVER_RELTOL = 1e-6
const DEFAULT_STEADY_ABSTOL = 1e-6
const DEFAULT_STEADY_RELTOL = 1e-4
const MARKET_PROJECTION_TOL = 1e-10

_steady_callback() =
    TerminateSteadyState(DEFAULT_STEADY_ABSTOL, DEFAULT_STEADY_RELTOL)

function _solve_primary(prob)
    solve(prob, SSPRK432(; stage_limiter!);
        callback=_steady_callback(),
        abstol=DEFAULT_SOLVER_ABSTOL,
        reltol=DEFAULT_SOLVER_RELTOL)
end

"""
    sim_init(p; from::Symbol = :zeros, t_end=1000.0)

Return a tuple of initial values `(u0, y0, extra...)` matching the scenario `p`.
`from = :zeros` produces zeros; `from = :oa` solves Open Access once and
returns its steady state as a warm start (u*, y*, extra set to defaults).
"""
function sim_init(p; from::Symbol=:zeros, t_end=1000.0)
    N = p.N
    pol = hasproperty(p, :policy) ? p.policy : OpenAccess()

    if from == :zeros
        if pol isa TradableUseRights
            return (zeros(N), 1.0, 0.0)
        elseif pol isa ProtectedAreaTwoPop
            return (zeros(N), 1.0, 1.0)
        else
            return (zeros(N), 1.0)
        end
    elseif from == :oa
        # Solve the explicit open-access system for the same realized actors.
        # Zero-regulation policy equations are tested to be open-access
        # equivalent, but may still carry policy-specific auxiliary states.
        oa = scenario(p; policy=OpenAccess())
        initVals = [zeros(N); 1.0]
        prob = ODEProblem(dxdt, initVals, (0.0, t_end), oa)
        sol = _solve_primary(prob)
        # Copy back u*, y* and keep extra states at defaults
        if pol isa TradableUseRights
            return (sol[1:N, end-2], sol[N+1, end-2], 0.0)
        elseif pol isa ProtectedAreaTwoPop
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
    x[p.N+1] = clamp(x[p.N+1], 0.0, 1.0)
    for j in p.N+2:length(x)
        x[j] = max(0.0, x[j])
    end

    pol = hasproperty(p, :policy) ? p.policy : OpenAccess()
    if pol isa ProtectedAreaTwoPop && length(x) >= p.N + 2
        x[p.N+2] = clamp(x[p.N+2], 0.0, 1.0)
    end
end

function sim(s; u0=nothing, y0=1.0, ϕ0=0.0, regulation=0.0, start_from_OA=false, t_end=1000.0)
    sample!(s; force=false)
    tspan = (0.0, t_end)
    p = s.regulate(s, regulation)
    pol = hasproperty(p, :policy) ? p.policy : OpenAccess()

    # 2. Initial Conditions
    if u0 === nothing
        # Default start
        if pol isa TradableUseRights
            u0_val = fill(1e-5, s.N)
            y0_val = 1.0
            extra_val = [ϕ0]
        elseif pol isa ProtectedAreaTwoPop
            u0_val = zeros(s.N)
            y0_val = 1.0
            extra_val = [y0_val]
        else
            u0_val = zeros(s.N)
            y0_val = 1.0
            extra_val = Float64[]
        end
        initVals = vcat(u0_val, y0_val, extra_val)
    else
        # User provided u0
        if pol isa TradableUseRights
            initVals = [u0; y0; ϕ0]
        elseif pol isa ProtectedAreaTwoPop
            initVals = [u0; y0; y0]
        else
            initVals = [u0; y0]
        end
    end

    if start_from_OA
        oa = scenario(s; policy=OpenAccess())
        oa_init = [initVals[1:s.N]; initVals[s.N+1]]
        oaprob = ODEProblem(dxdt, oa_init, tspan, oa)
        oasol = _solve_primary(oaprob)
        initVals[1:s.N+1] = oasol[1:s.N+1, end-2]
        if pol isa ProtectedArea
            scale = protected_pressure_scale(initVals[s.N+1], p.regulation, pol.m)
            initVals[1:s.N] .*= scale
        end
    end

    # Policy changes can tighten feasible use bounds at the intervention time.
    stage_limiter!(initVals, nothing, p, 0.0)

    prob = ODEProblem(dxdt, initVals, tspan, p)
    # try primary algorithm with limiter; on failure, try fallbacks
    function _try_solve(prob)
        function valid(sol)
            SciMLBase.successful_retcode(sol) || return false
            tol = 1e-7
            try
                for (x, t) in zip(sol.u, sol.t)
                    all(isfinite, x) || return false
                    (-tol <= x[p.N+1] <= 1.0 + tol) || return false
                    all(x[1:p.N] .>= -tol) || return false
                    all(x[1:p.N] .<= p.limit(x, p, t) .+ tol) || return false
                    all(x[p.N+1:end] .>= -tol) || return false
                    if pol isa ProtectedAreaTwoPop
                        x[p.N+2] <= 1.0 + tol || return false
                    end
                end
            catch
                return false
            end
            return true
        end

        # 1) SSPRK with limiter
        try
            sol = _solve_primary(prob)
            valid(sol) && return sol
        catch
        end
        # 2) Stiff fallback
        try
            sol = solve(prob, Rosenbrock23(); callback=_steady_callback(),
                abstol=DEFAULT_SOLVER_ABSTOL, reltol=DEFAULT_SOLVER_RELTOL)
            valid(sol) && return sol
        catch
        end
        # 3) Adaptive non-stiff fallback with the same feasibility projection.
        sol = solve(prob, Tsit5(; stage_limiter!); callback=_steady_callback(),
            abstol=DEFAULT_SOLVER_ABSTOL, reltol=DEFAULT_SOLVER_RELTOL)
        valid(sol) || error("All simulation algorithms failed or violated model bounds")
        return sol
    end
    sol = _try_solve(prob)
    return sol
end
