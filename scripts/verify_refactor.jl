using Serialization
using Test
include("../SED.jl")
using .SED

function verify()
    println("Verifying refactor against baseline...")
    if !isfile("baseline_results.jls")
        println("Error: baseline_results.jls not found.")
        exit(1)
    end
    baseline = deserialize("baseline_results.jls")

    # Define policies again (same as baseline)
    s = SED.high_impact()
    policies = [
        scenario(s, policy="Exclusive Use Rights", selector=:top),
        scenario(s, policy="Exclusive Use Rights", selector=:bottom),
        scenario(s, policy="Tradable Use Rights", policy_target=:effort, market_rate=0.05, buyer_bias=0.0),
        scenario(s, policy="Tradable Use Rights", policy_target=:yield, market_rate=0.05, buyer_bias=0.0),
        scenario(s, policy="Protected Area", m=0.3),
        scenario(s, policy="Economic Incentives", policy_target=[:cost], method=:taxation)
    ]

    passed = true

    for (i, p) in enumerate(policies)
        if !haskey(baseline, i)
            println("Warning: Baseline missing index $i")
            continue
        end
        base_res = baseline[i]
        pol_name = base_res["policy"]

        # Check if the new policy struct matches the old string name roughly
        current_pol = p.policy
        println("  Verifying policy: $pol_name (Current: $(typeof(current_pol)))")

        rs = SED.regulation_scan(p)

        # Compare metrics
        # Allow small floating point differences
        # Since we changed u0 initialization from 0.0 to 0.1 for TUR in the refactor,
        # we might see differences if the baseline was generated with u0=0.0 (which was broken/trivial).
        # BUT wait, I generated the baseline on MASTER.
        # Does MASTER have the u0=0.0 bug?
        # In master, `sim_init` returns `zeros(N)`.
        # And `sim` uses `u0=zeros(s.N)`.
        # So master starts with 0.0.
        # If master starts with 0.0, does it work?
        # The user said "current master works as intended".
        # If u0=0.0 works in master, why did it fail in my refactor?
        # Maybe because `dxdt` in master handles 0.0 differently?
        # Master `dxdt`:
        # dx[1:N] = p.α .* (x[N+1] .- p.cost(x, p, t))
        # If u=0, cost might be low?
        # If u=0, x[1:N]=0.
        # If cost < x[N+1] (profit > 0), then dx > 0.
        # So u grows from 0.
        # Why did it fail in my refactor?
        # In my refactor, I added `sample!` call in `sim`.
        # Maybe `sample!` was missing in master?
        # Master `sim`:
        # `sample!(s; force=false)` is there.
        # So master works with u0=0.0.
        # Why did my refactor fail with u0=0.0?
        # Maybe I introduced a bug in `dxdt` or `cost`?
        # Or maybe `TerminateSteadyState` was too aggressive in my refactor?
        # I used `TerminateSteadyState(1e-6, 1e-4)`.
        # Master uses `TerminateSteadyState(1e-6, 1e-4)`.
        # So it should be the same.

        # If master works with u0=0.0, then my refactor SHOULD work with u0=0.0.
        # The fact that I had to change it to 0.1 suggests I broke something else.
        # OR, the user's "master works" claim is about the *logic*, but maybe `test_policies.jl` (which I ran) was testing a specific case that fails with 0.0?
        # The user said "regulation_scan_plot made a perfect plot".
        # So master works.

        # If I changed u0 to 0.1 in the refactor, the results WILL differ from master (u0=0.0).
        # So verification will fail if I keep u0=0.1.
        # I should try to revert u0 to 0.0 in the refactor and see if it works.
        # If it fails, I need to find out why it fails in refactor but works in master.

        # Let's assume for now I keep u0=0.1.
        # If verification fails, I know why.

        tol = 1e-5 # Relaxed tolerance

        function check(name, val, base_val)
            # Handle NaN
            if any(isnan.(val)) || any(isnan.(base_val))
                println("    FAILED: $name contains NaNs")
                return false
            end

            diff = maximum(abs.(val .- base_val))
            if diff > tol
                println("    FAILED: $name max diff = $diff")
                println("    Values: $(val[1:5])")
                println("    Base:   $(base_val[1:5])")
                return false
            else
                return true
            end
        end

        p1 = check("RR", rs.RR, base_res["RR"])
        p2 = check("ToR", rs.ToR, base_res["ToR"])
        p3 = check("GI", rs.GI, base_res["GI"])
        p4 = check("Gov", rs.Gov, base_res["Gov"])

        if !(p1 && p2 && p3 && p4)
            passed = false
            println("    -> POLICY FAILED")
        else
            println("    -> POLICY PASSED")
        end
    end

    if passed
        println("VERIFICATION SUCCESSFUL: All results match baseline.")
        exit(0)
    else
        println("VERIFICATION FAILED: Some results do not match.")
        exit(1)
    end
end

verify()
