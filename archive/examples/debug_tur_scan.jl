using SED
using Statistics

# Setup TUR scenario
s = scenario(high_impact(), policy="Tradable Use Rights", policy_target=:effort, market_rate=0.05, buyer_bias=0.0)

# Run scan manually
println("Running regulation scan for TUR...")
rs = regulation_scan(s; m=20) # Low resolution for speed

println("Scan Results:")
println("r\tRR\tWR\tTR\tToR")
for i in 1:length(rs.r)
    println("$(round(rs.r[i], digits=2))\t$(round(rs.RR[i], digits=4))\t$(round(rs.WR[i], digits=4))\t$(round(rs.TR[i], digits=4))\t$(round(rs.ToR[i], digits=4))")
end

# Check if TR is all zeros
if all(rs.TR .== 0.0)
    println("\nWARNING: TR (Trade Revenue) is all zeros!")
else
    println("\nTR has non-zero values.")
end

# Check if ToR is flat (variance near zero)
if var(rs.ToR) < 1e-6
    println("WARNING: ToR (Total Revenue) is flat!")
else
    println("ToR varies.")
end
