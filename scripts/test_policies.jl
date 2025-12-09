include("../SED.jl")
using .SED
getdata_or_values(v) = hasproperty(v, :data) ? v.data : v

tourism_factor = 0.001

s = scenario(high_impact())

policies = [
    scenario(s, policy="Exclusive Use Rights", selector=:top),
    scenario(s, policy="Exclusive Use Rights", selector=:bottom),
    scenario(s, policy="Tradable Use Rights", policy_target=:effort, market_rate=0.05, buyer_bias=0.0),
    scenario(s, policy="Tradable Use Rights", policy_target=:effort, market_rate=0.05, buyer_bias=+0.9),
    scenario(s, policy="Tradable Use Rights", policy_target=:effort, market_rate=0.05, buyer_bias=-0.9),
    scenario(s, policy="Tradable Use Rights", policy_target=:yield, market_rate=0.05, buyer_bias=0.0),
    scenario(s, policy="Protected Area", m=0.3),
    let
        base_pa = scenario(s, policy="Protected Area", m=0.3)
        change(base_pa, income_extra_fun=(x, p, t) -> fill(tourism_factor * p.regulation, p.N))
    end
]

sols = [sim(policy, regulation=0.75) for policy in policies]

SED.phase_plot(sols[4])