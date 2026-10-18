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
    # A literal economic intervention uses the original common numeraire.
    # The generic EconomicIncentives income hook is intentionally reduced-form.
    if name == "economic"
        resource = sum(state[1:N]) * y * (1 - royalty)
        wages = sum(((1 + gear) * (1 + effort) .* potentials .- state[1:N]) .*
            thresholds .* ((1 + outside) / (1 + gear)))
        total = resource + wages
    else
        resource = sum(inc.resource)
        total = sum(inc.total)
    end
    values = [y, participation, sum(state[1:N]), resource, total, price]
    for level in (0.21, 0.51, 0.81)
        push!(values, Γ(level, p; x=state), Φ(level, p; x=state))
    end
    println(name * "," * join(values, ","))
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
econ = scenario(population;
    w̃=dist(data=thresholds ./ ((1 - rho) * (1 + g))),
    ū=dist(data=potentials .* (1 + g)))
report("economic", sim(econ; t_end=6000.0); royalty=rho, gear=g)
