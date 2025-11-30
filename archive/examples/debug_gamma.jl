using SED
println("Checking SED.γ...")
try
    println(SED.γ)
    println("SED.γ exists.")
catch e
    println("SED.γ DOES NOT EXIST.")
    showerror(stdout, e)
    println()
end

println("Checking scenario...")
try
    s = scenario((N=10, w̃=dist(mean=0.5, sigma=0.1, distribution=LogNormal), ū=dist(mean=1.0, sigma=0.1, distribution=Normal), R=ones(10)))
    println("Scenario created.")
    println("s.γ is: ", s.γ)
catch e
    println("Scenario creation FAILED.")
    showerror(stdout, e)
    println()
end
