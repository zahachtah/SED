using OrdinaryDiffEq
using DiffEqCallbacks: TerminateSteadyState

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

