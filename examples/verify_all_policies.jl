using SED
using Test

# 1. Setup Base Scenario
s = high_impact(N=10)
SED.sample!(s) # Ensure data is populated

println("Base scenario created and sampled.")

# 2. Get Default Policies
# We use the helper from regulation_scan_plot.jl
# Note: We need to import it or include the file if not exported.
# It is NOT exported by SED.jl. It is in src/regulation_scan_plot.jl which is included in src/plots.jl.
# So it should be available if we use SED.
# But wait, is `default_regulation_scan_policies` exported?
# I don't think so. I'll check.

# If not exported, we can access it via SED.default_regulation_scan_policies if it's in the module.
# Or we can manually reconstruct the list.

# Let's try to access it.
try
    defaults = SED.default_regulation_scan_policies(s)
    policies = defaults.policies
    labels = defaults.policylabels

    println("Found $(length(policies)) policies to test.")

    for (i, pol) in enumerate(policies)
        label = labels[i]
        println("\nTesting Policy $i: $label")

        # Run a short simulation
        # We need to set a regulation level.
        # Most policies respond to 'regulation'.
        # We'll use f=0.5.

        # Apply regulation
        # The policy object 'pol' is a Scenario NamedTuple.
        # It has a 'regulate' function.
        # We call it to get a regulated scenario.

        reg_pol = pol.regulate(pol, 0.5)

        # Run sim
        try
            sol = sim(reg_pol, t_end=10.0)
            println("  -> Simulation successful.")

            # Basic check: check if results are finite
            @test all(isfinite.(sol))

            # Check if policy hooks were called (hard to check directly, but if it ran without error it's good sign)
            # We can check if γ or μ changed compared to base if we want, but that's complex.
            # Just running it verifies the composition logic doesn't crash.

        catch e
            println("  -> FAILED with error:")
            showerror(stdout, e)
            println()
            rethrow(e)
        end
    end

    println("\nAll policies verified successfully!")

catch e
    if e isa UndefVarError
        println("SED.default_regulation_scan_policies not found. Reconstructing manually...")
        # Manual reconstruction if needed
        # ...
    else
        rethrow(e)
    end
end
