if !isdefined(Main, :SED)
    error("Load SED first: include(\"SED.jl\"); using .SED")
end
using .SED

"""
    regscan_warmstart_demo()

Runs regulation scans with and without warmstarts for a baseline scenario and
prints the chosen regulation under :Gov goal. Intended as a quick smoke check.
"""
function regscan_warmstart_demo()
    N = 80
    s = scenario(base(N=N))
    R1 = regulation_scan(s; m=30, warmstart=:none)
    R2 = regulation_scan(s; m=30, warmstart=:chain)
    println("Gov (no warmstart): reg=", round(R1.r[R1.oGov], digits=2))
    println("Gov (chain warmstart): reg=", round(R2.r[R2.oGov], digits=2))
    return (; R1, R2)
end

