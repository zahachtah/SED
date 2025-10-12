using OrdinaryDiffEq
using DiffEqCallbacks: TerminateSteadyState

"""
    sim_init(p; from::Symbol = :zeros, t_end=1000.0)

Return a tuple of initial values `(u0, y0, extra...)` matching the scenario `p`.
`from = :zeros` produces zeros; `from = :oa` solves Open Access once and
returns its steady state as a warm start (u*, y*, extra set to defaults).
"""
function sim_init(p; from::Symbol = :zeros, t_end=1000.0)
    N = p.N
    if from == :zeros
        if get(p, :policy, "") == "Tradable Use Rights"
            return (zeros(N), 1.0, 0.0)
        elseif get(p, :policy, "") == "Protected Area Two Pop"
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
        if get(p, :policy, "") == "Tradable Use Rights"
            return (sol[1:N, end-2], sol[N+1, end-2], 0.0)
        elseif get(p, :policy, "") == "Protected Area Two Pop"
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
    dx[1:N] = p.α .* (x[N+1] .- p.γ(x, p, t))
    dx[N+1] = x[N+1] * ((1 - x[N+1]) - sum(x[1:N]))
    p.ϕ(dx, x, p, t)
end

function stage_limiter!(x, integrator, p, t)
    x[1:p.N] .= ifelse.(x[1:p.N] .< 0.0, 0.0,
        ifelse.(x[1:p.N] .> (p.μ(x, p, t)), p.μ(x, p, t), x[1:p.N]))
    for j in p.N+1:length(x)
        x[j] = max(0.0, x[j])
    end
end

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
