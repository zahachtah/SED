using SED

N = 32
thresholds = [0.08 + 0.85 * (i / (N + 1))^2 for i in 1:N]
potentials = [0.2 + 2.2 * i / (N + 1) for i in 1:N]
potentials .*= 1.4 / sum(potentials)
population = scenario(base(N=N); α=0.05,
    w̃=dist(data=thresholds), ū=dist(data=potentials))

function report(name, sol; royalty=0.0, gear=0.0, effort=0.0, outside=0.0)
    p = sol.prob.p
    state = sol.u[end]
    y = state[N + 1]
    limits = p.limit(state, p, sol.t[end])
    participation = sum(state[1:N] ./ limits) / N
    inc = incomes(state, p)
    price = p.policy isa TradableUseRights ? state[N + 2] : 0.0
    values = [y, participation, sum(state[1:N]), sum(inc.resource), sum(inc.total), price,
        sum(inc.resource_rent), sum(inc.opportunity_cost), sum(inc.outside_income),
        sum(inc.outside_income_0), sum(inc.state_revenue), sum(inc.gross_resource_revenue)]
    for level in (0.21, 0.51, 0.81)
        push!(values, Γ(level, p; x=state), Φ(level, p; x=state))
    end
    println(name * "," * join(values, ","))
    for i in 1:N
        components = [inc.resource[i], inc.resource_rent[i], inc.opportunity_cost[i],
            inc.outside_income[i], inc.outside_income_0[i], inc.rights_transfer[i],
            inc.state_revenue[i], inc.total[i], inc.gross_resource_revenue[i]]
        println("actor," * name * "," * string(i - 1) * "," * join(components, ","))
    end
end

report("none", sim(population; t_end=6000.0))
report("access", sim(scenario(population; policy=ExclusiveUseRights(:bottom, false));
    regulation=0.375, start_from_OA=true, t_end=6000.0))
for historical in (false, true)
    name = historical ? "rights_historical" : "rights"
    report(name, sim(scenario(population; policy=TradableUseRights(:effort, 0.05, 0.0, historical));
        regulation=0.5, start_from_OA=true, t_end=6000.0))
end
report("catch", sim(scenario(population; policy=TradableUseRights(:yield, 0.05, 0.0, false));
    regulation=0.82, start_from_OA=true, t_end=6000.0))
report("pa", sim(scenario(population; policy=ProtectedArea(0.3));
    regulation=0.3, start_from_OA=true, t_end=6000.0))
g = 0.35
rho = 0.2
oa = sim(population; t_end=6000.0)
for (name, royalty, gear, effort, outside) in (
        ("economic", rho, g, 0.0, 0.0),
        ("royalty", 0.3, 0.0, 0.0, 0.0),
        ("gear", 0.0, 0.5, 0.0, 0.0),
        ("effort", 0.0, 0.0, -0.3, 0.0),
        ("outside", 0.0, 0.0, 0.0, 0.4))
    multiplier = 1 + gear
    econ = scenario(population;
        w̃=dist(data=thresholds .* ((1 + outside) / ((1 - royalty) * multiplier))),
        ū=dist(data=potentials .* (multiplier * (1 + effort))),
        income_cost_fun=(x, p, t) -> thresholds .* ((1 + outside) / multiplier),
        resource_factor_fun=(x, p, t) -> 1 - royalty,
        income_state_fun=(x, p, t) -> royalty .* x[1:p.N] .* x[p.N+1])
    report(name, sim(econ; u0=multiplier .* oa[1:N, end-2], y0=oa[N+1, end-2], t_end=6000.0))
end
