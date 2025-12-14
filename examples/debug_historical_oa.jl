include("../SED.jl")
using .SED
using Distributions
using OrdinaryDiffEq
using DiffEqCallbacks
using LinearAlgebra

println("Debugging OA simulation for Historical Use Rights...")

# Reconstruct T from user context but modify to force sparse OA
s_base = SED.high_impact()
# Make 50% of users have very high cost (low efficiency) so they don't fish in OA
# We can modify w̃ (opportunity cost) or efficiency.
# Let's modify w̃ to be very high for half the population.
N = s_base.N
half_N = div(N, 2)
w_data = [fill(0.1, half_N); fill(100.0, N - half_N)] # Low cost vs High cost
T = (; s_base..., w̃=SED.dist(data=w_data), gender=dist(mean=0.5, distribution=Bernoulli, random=true))

# Create OA scenario (this is what regulate() does internally)
s_oa = SED.change(SED.scenario(T), policy=SED.OpenAccess())

# CRITICAL: Sample the scenario!
println("Sampling scenario...")
SED.sample!(s_oa)

# Setup problem
u0 = fill(0.1, s_oa.N)
y0 = 1.0
oaprob = ODEProblem(SED.dxdt, [u0; y0], (0.0, 1000.0), s_oa)

println("Solving OA problem...")
try
    # Try with default solver first (what was crashing)
    # oasol = solve(oaprob, SSPRK432(; stage_limiter!), callback=TerminateSteadyState(1e-6, 1e-4))

    # Try with the robust solver setup I added
    oasol = solve(oaprob, Rosenbrock23(),
        callback=TerminateSteadyState(1e-6, 1e-4),
        reltol=1e-4, abstol=1e-4, maxiters=1e5)

    println("Solver returned: $(oasol.retcode) (Type: $(typeof(oasol.retcode)))")

    if oasol.retcode != :Success && oasol.retcode != :Terminated && string(oasol.retcode) != "Success"
        println("Solver failed!")
    else
        println("Solver succeeded!")
        hur = oasol[1:s_oa.N, end]
        println("Historical Use Rights (first 5): $(hur[1:5])")
        println("Total Effort: $(sum(hur))")
        println("Min Effort: $(minimum(hur))")
        println("Max Effort: $(maximum(hur))")

        # Check if it's uniform (which would be bad for historical rights)
        if std(hur) < 1e-6
            println("WARNING: Historical effort is uniform!")
        else
            println("Historical effort is NOT uniform (Good). Std: $(std(hur))")
        end

        # Calculate R
        denom = sum(hur)
        R_hist = hur ./ denom
        println("R_hist (first 5): $(R_hist[1:5])")
        println("R_hist sum: $(sum(R_hist))")

        # Run comparative simulation
        println("\nRunning comparative simulations...")

        # 1. Historical
        s_hist = SED.scenario(T, policy="Tradable Use Rights", policy_target=:effort, market_rate=0.05, buyer_bias=0.0, historical_use_rights=true)
        # We need to manually inject the sampled data into s_hist because scenario(T) creates new SEDists
        # But wait, T has the SEDists. If we reuse T, they share the source.
        # But T.α is a SEDist.
        # Let's just rely on sample! being called inside sim() or regulate().
        # But regulate() for historical calls sample!(s_oa).
        # So s_hist will be sampled.

        sol_hist = SED.sim(s_hist, regulation=0.5)
        println("Hist Sol Retcode: $(sol_hist.retcode)")
        u_hist = sol_hist[1:s_hist.N, end]
        println("u_hist (first 5): $(u_hist[1:5])")

        # 2. Uniform (Standard)
        s_unif = SED.scenario(T, policy="Tradable Use Rights", policy_target=:effort, market_rate=0.05, buyer_bias=0.0, historical_use_rights=false)
        # We must ensure s_unif uses the SAME sampled parameters as s_hist for fair comparison.
        # We can copy the data from s_hist's SEDists to s_unif's SEDists?
        # Or just force them to be the same.
        # Since T was used for both, and T's SEDists are mutable, if they were sampled once, they hold the data.
        # Let's check if T's SEDists have data.

        sol_unif = SED.sim(s_unif, regulation=0.5)
        println("Unif Sol Retcode: $(sol_unif.retcode)")
        u_unif = sol_unif[1:s_unif.N, end]
        println("u_unif (first 5): $(u_unif[1:5])")

        # Compare Effort (Should be identical due to Coase Theorem in perfect market)
        diff_u = norm(u_hist - u_unif)
        println("Difference in Effort: $diff_u (Expected ~0.0)")

        # Compare Incomes (Should be DIFFERENT due to wealth effect of R)
        inc_hist = SED.incomes(sol_hist)
        inc_unif = SED.incomes(sol_unif)

        diff_inc = norm(inc_hist.total - inc_unif.total)
        println("Difference in Net Income (Total): $diff_inc")

        if diff_inc > 1e-6
            println("SUCCESS: Historical Use Rights produces different INCOMES!")
        else
            println("FAILURE: Incomes are identical.")
        end

        # Check if R was actually different in the regulated scenarios
        # We can't easily check internal R of sim, but we can call regulate manually to check
        p_hist = SED.regulate(s_hist, 0.5)
        p_unif = SED.regulate(s_unif, 0.5)

        println("p_hist.R (first 5): $(p_hist.R[1:5])")
        println("p_unif.R (first 5): $(p_unif.R[1:5])")

        if p_hist.R == p_unif.R
            println("WARNING: Regulated R vectors are IDENTICAL!")
        else
            println("Regulated R vectors are DIFFERENT.")
        end
    end

catch e
    println("Solver crashed!")
    showerror(stdout, e)
    println()
    if isa(e, ErrorException)
        println("Error message: $(e.msg)")
    end
    # rethrow(e) # Don't rethrow to see output
end
