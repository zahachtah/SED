if !isdefined(Main, :SED)
    error("Load SED first: include(\"SED.jl\"); using .SED")
end
using .SED

"""
    with_policy_demo()

Demonstrates the function-based policy wrapper `with_policy` by modifying the
incentive function γ and running a short simulation.
"""
function with_policy_demo()
    N = 80
    s0 = scenario(base(N=N))
    # Simple policy: add a small constant bonus to incentives
    bonus = 0.05
    γ_bonus(x, p, t) = p.w̃ .+ bonus
    s2 = with_policy(s0; γ=γ_bonus, label="γ + bonus")
    sol = sim(s2; regulation=0.2)
    inc = incomes(sol)
    println("label=", get(s2, :label, "(none)"),
            "  y*=", round(sol.u[end][end], digits=3),
            "  ToR=", round(sum(inc.total), digits=3))
    return sol
end
