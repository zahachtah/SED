if !isdefined(Main, :SED)
    error("Load SED first: include(\"SED.jl\"); using .SED")
end
using .SED

"""
    policy_kits_demo()

Demonstrates building policies via kits and applying them with `with_policy`.
"""
function policy_kits_demo()
    N = 100
    s0 = scenario(base(N=N))

    # Exclusive Use Rights: select top-n by w̃
    top_selector = (w̃, n) -> sortperm(w̃, rev=true)[1:n]
    eur = with_policy(s0; exclusive_use_rights_kit(; selector=top_selector)...)
    sol_eur = sim(eur; regulation=0.3)
    inc_eur = incomes(sol_eur)
    println("EUR ToR=", round(sum(inc_eur.total), digits=3))

    # TUR (effort)
    tur = with_policy(s0; tradable_use_rights_kit(; target=:effort, market_rate=0.05)...)
    sol_tur = sim(tur; regulation=0.3)
    inc_tur = incomes(sol_tur)
    println("TUR ToR=", round(sum(inc_tur.total), digits=3))

    # Protected Area
    pa = with_policy(s0; protected_area_kit(; m=0.3)...)
    sol_pa = sim(pa; regulation=0.3)
    inc_pa = incomes(sol_pa)
    println("PA ToR=", round(sum(inc_pa.total), digits=3))

    return (; eur, tur, pa)
end

