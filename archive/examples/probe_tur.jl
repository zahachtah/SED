using SED
using Statistics

function check_tur()
    println("Probing TUR Yield Revenue...")
    try
        # Define a standard scenario
        T_def = (
            N=100,
            health=dist(mean=0, sigma=2.0, distribution=Normal, dependency_fun="1/(1+exp(-2-independent))"),
            gender=dist(mean=0.5, distribution=Bernoulli, random=true),
            parental=dist(min=0.1, max=1.0, distribution=LogNormal),
            time=dist(dependency_fun="health*(1-gender*0.5)*independent", min=0, max=1),
            efficiency=dist(min=0.015, max=0.2, dependency_fun="1*parental*(1-gender*0.2)*independent", normalize=false),
            AIO=dist(min=0.1, max=1.6, distribution=LogNormal, dependency_fun="0.02*parental*(1-gender*0.2)*independent"),
            K=2.0,
            ū=dist(min=-0.1, max=0.1, dependency_fun="time*efficiency"),
            w̃=dist(min=-0.1, max=0.1, dependency_fun="(AIO ./ efficiency) .+ independent"),
            α=dist(min=0.1, max=0.1, distribution=Uniform)
        )
        T = SED.scenario(T_def)
        SED.sample!(T)

        # Create TUR Yield policy
        # Try to be robust to signature changes (kwargs vs args)
        # Using the kit if available, or manual construction
        try
            pol_kit = SED.tradable_use_rights_kit(target=:yield, market_rate=0.05)
            # Apply kit to scenario
            # Note: with_policy might have changed signature too, but let's try standard way
            s = SED.with_policy(T; pol_kit...)
        catch e
            println("Failed to create policy with standard kit: $e")
            return false
        end

        # Run at f=0.0 (OA) and f=0.25 (Expected Peak/Hump)
        sol_0 = SED.sim(s, regulation=0.0)
        sol_25 = SED.sim(s, regulation=0.25)

        if sol_0.retcode != :Success && string(sol_0.retcode) != "Success" && string(sol_0.retcode) != "Terminated"
            println("Simulation failed at f=0.0: $(sol_0.retcode)")
            return false
        end
        if sol_25.retcode != :Success && string(sol_25.retcode) != "Success" && string(sol_25.retcode) != "Terminated"
            println("Simulation failed at f=0.25: $(sol_25.retcode)")
            return false
        end

        # Calculate Revenue
        inc_0 = SED.incomes(sol_0)
        rev_0 = sum(inc_0.resource)

        inc_25 = SED.incomes(sol_25)
        rev_25 = sum(inc_25.resource)

        println("Revenue @ f=0.00: $rev_0")
        println("Revenue @ f=0.25: $rev_25")

        # Check for Hump: Rev(0.25) should be significantly higher than Rev(0.0)
        # OA is usually overfished, so regulation increases yield/revenue.
        if rev_25 > rev_0 * 1.1
            println("STATUS: WORKING (Hump detected)")
            return true
        else
            println("STATUS: BROKEN (Flat or decreasing)")
            return false
        end

    catch e
        println("Probe crashed: $e")
        return false
    end
end

if check_tur()
    exit(0)
else
    exit(1)
end
