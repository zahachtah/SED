using Test

function fixed_scenario()
    thresholds = [0.1, 0.2, 0.8, 1.2]
    impacts = [0.1, 0.2, 0.3, 0.4]
    s = scenario((
        N=4,
        α=0.1,
        w̃=dist(data=thresholds),
        ū=dist(data=impacts),
        R=ones(4),
    ))
    sample!(s)
    return s, thresholds, impacts
end

@testset "Paper-to-code alignment" begin
    s, thresholds, impacts = fixed_scenario()

    @testset "Participation and required-participation curves" begin
        # P(y) counts actors with the strict paper criterion Θᵢ < y.
        @test Γ(0.8, s) == 2 / 4

        # At y=0.8, replacement pressure is 0.2. Ordered impacts 0.1 and
        # half of 0.2 require 1.5 equivalent users out of four.
        @test Φ(0.8, s) ≈ 1.5 / 4

        # Θᵢ > 1 actors cannot be active on the plotted resource domain.
        # At y=0 the eligible actors cannot supply replacement pressure 1,
        # so the required-participation curve is explicitly infeasible.
        @test isnan(Φ(0.0, s))
        @test Φ(1.0, s) == 0.0
    end

    @testset "Open-access dynamics and bounds" begin
        sol = sim(s; t_end=300.0)
        x = sol.u[end]
        @test all((0.0 .<= x[1:s.N]) .& (x[1:s.N] .<= impacts))
        @test 0.0 <= x[s.N+1] <= 1.0 + 1e-8

        # Use the explicit OpenAccess system so policy-specific auxiliary
        # states cannot affect the baseline warm start.
        tur = scenario(s; policy=TradableUseRights(:effort, 0.05, 0.0, false))
        oa_init = sim_init(tur; from=:oa, t_end=300.0)
        @test oa_init[1] ≈ sol[1:s.N, end-2]
        @test oa_init[2] ≈ sol[s.N+1, end-2]
    end

    @testset "Positive-attractor stability" begin
        # A crossing between thresholds has a unique boundary equilibrium.
        gap = scenario((
            N=2,
            α=0.1,
            w̃=dist(data=[0.25, 0.75]),
            ū=dist(data=[0.4, 0.4]),
            R=ones(2),
        ))
        sample!(gap)
        for (u0, y0) in (([0.0, 0.0], 1.0),
                ([0.4, 0.4], 0.2),
                ([0.1, 0.3], 0.9))
            sol = sim(gap; u0, y0, t_end=500.0)
            @test sol.u[end][1:2] ≈ [0.4, 0.0] atol=2e-3
            @test sol.u[end][3] ≈ 0.6 atol=2e-3
        end

        # At an exact threshold, resource balance selects the marginal
        # actor's unique interior use.
        marginal = scenario((
            N=2,
            α=0.1,
            w̃=dist(data=[0.4, 0.9]),
            ū=dist(data=[0.8, 0.1]),
            R=ones(2),
        ))
        sample!(marginal)
        for (u0, y0) in (([0.0, 0.0], 1.0), ([0.8, 0.1], 0.2))
            sol = sim(marginal; u0, y0, t_end=1000.0)
            @test sol.u[end][1:2] ≈ [0.6, 0.0] atol=2e-3
            @test sol.u[end][3] ≈ 0.4 atol=2e-3
        end
    end

    @testset "Zero regulation is open-access equivalent" begin
        policies = (
            ExclusiveUseRights(:top, false),
            TradableUseRights(:effort, 0.05, 0.0, false),
            ProtectedArea(0.3),
            ProtectedAreaTwoPop(0.3),
            EconomicIncentives([:cost, :limit], :multiplicative),
            Development(0.5, 0.5),
        )
        oa_x = [zeros(s.N); 0.5]
        oa_dx = zeros(length(oa_x))
        SED.dxdt(oa_dx, oa_x, s, 0.0)

        for policy in policies
            p0 = regulate(scenario(s; policy), 0.0)
            extra = policy isa TradableUseRights ? [0.25] :
                    policy isa ProtectedAreaTwoPop ? [0.7] : Float64[]
            x = [zeros(s.N); 0.5; extra]
            dx = zeros(length(x))
            SED.dxdt(dx, x, p0, 0.0)

            @test p0.cost(x, p0, 0.0) ≈ thresholds
            @test p0.limit(x, p0, 0.0) ≈ impacts
            @test dx[1:s.N+1] ≈ oa_dx
            if policy isa TradableUseRights
                @test dx[end] == 0.0
                @test p0.income_extra_fun(x, p0, 0.0) == zeros(s.N)
            end
        end
    end

    @testset "Exclusive use rights" begin
        eur = scenario(s; policy=ExclusiveUseRights(:bottom, false))
        regulated = regulate(eur, 0.5)
        x = [zeros(s.N); 0.5]

        @test regulated.R == [1.0, 1.0, 0.0, 0.0]
        @test regulated.cost(x, regulated, 0.0) == thresholds .+ regulated.R

        # Selection follows the paper's exit-threshold ordering even when an
        # outside-opportunity field has a different rank order.
        ranked = scenario(merge(s, (opportunities=dist(data=reverse(thresholds)),));
            policy=ExclusiveUseRights(:bottom, false))
        sample!(ranked)
        ranked_regulated = regulate(ranked, 0.5)
        @test ranked_regulated.R == [1.0, 1.0, 0.0, 0.0]
    end

    @testset "Tradable use rights" begin
        tur = scenario(s; policy=TradableUseRights(:effort, 0.05, 0.0, false))
        regulated = regulate(tur, 0.6)
        price = 0.25
        x = [regulated.R; 0.5; price]

        @test sum(regulated.R) ≈ 0.4
        @test regulated.cost(x, regulated, 0.0) == thresholds .+ price
        @test sum(regulated.income_extra_fun(x, regulated, 0.0)) ≈ 0.0

        dx_balanced = zeros(length(x))
        SED.dxdt(dx_balanced, x, regulated, 0.0)
        @test dx_balanced[end] ≈ 0.0

        excess_x = [fill(0.2, s.N); 0.5; price]
        dx_excess = zeros(length(excess_x))
        SED.dxdt(dx_excess, excess_x, regulated, 0.0)
        @test dx_excess[end] > 0.0

        # Price is projected to the nonnegative half-line: a slack market at
        # zero price cannot produce a negative price derivative.
        slack_x = [zeros(s.N); 0.5; 0.0]
        dx_slack = zeros(length(slack_x))
        SED.dxdt(dx_slack, slack_x, regulated, 0.0)
        @test dx_slack[end] == 0.0

        policy_sol = sim(tur; regulation=0.6, start_from_OA=true, t_end=300.0)
        @test SED.SciMLBase.successful_retcode(policy_sol)
        @test all(isfinite, policy_sol.u[end])
        diagnostics = tradable_market_diagnostics(policy_sol)
        @test diagnostics.quota_violation <= 2e-4
        @test abs(diagnostics.price_rate) <= 2e-4
        @test diagnostics.complementarity_error <= 2e-4

        # Catch rights are priced per unit yu, so their marginal price wedge
        # is y*phi rather than the additive effort-right wedge phi.
        yield_tur = scenario(s; policy=TradableUseRights(:yield, 0.05, 0.0, false))
        yield_regulated = regulate(yield_tur, 0.6)
        yield_x = [yield_regulated.R; 0.5; price]
        @test yield_regulated.cost(yield_x, yield_regulated, 0.0) ==
              thresholds .+ 0.5price

        # Curve metrics use the supplied equilibrium market-price state.
        @test Γ(0.5, regulated; x=x) ==
              sum((thresholds .+ price) .< 0.5) / s.N
        @test Φ(0.5, regulated; x=x) != Φ(0.5, regulated)

        # Historical use determines eligibility, after which the quota is
        # divided equally among all actors active under open access.
        historical_tur =
            scenario(s; policy=TradableUseRights(:effort, 0.05, 0.0, true))
        historical_regulated = regulate(historical_tur, 0.6)
        open_access = sim(s; t_end=1000.0)
        historical_users = open_access[1:s.N, end-1] .> 0.0
        expected_rights =
            historical_users .* (0.4 / count(historical_users))
        @test historical_regulated.R ≈ expected_rights
        @test length(unique(historical_regulated.R[historical_users])) == 1

        # The same Q and historical eligibility rule apply when rights are
        # denominated in catch y*u_i rather than effort u_i.
        historical_yield =
            scenario(s; policy=TradableUseRights(:yield, 0.05, 0.0, true))
        historical_yield_regulated = regulate(historical_yield, 0.6)
        @test historical_yield_regulated.R ≈ expected_rights
        @test sum(historical_yield_regulated.R) ≈ 0.4
    end

    @testset "Protected area reduced form" begin
        pa = scenario(s; policy=ProtectedArea(0.3))
        regulated = regulate(pa, 0.25)
        x = [zeros(s.N); 0.5]

        @test regulated.cost(x, regulated, 0.0) ≈ thresholds ./ 0.75

        y = 0.5
        expected_y_p = ((1 - 0.3) + sqrt((1 - 0.3)^2 + 4 * 0.3 * y)) / 2
        @test SED.yₚ(y, 0.25, 0.3) ≈ expected_y_p

        h = (0.25 / 0.75) * 0.3 * (expected_y_p - y) / y
        expected_scale = (1 - y) / (1 - y + h)
        @test SED.protected_pressure_scale(y, 0.25, 0.3) ≈ expected_scale
        @test regulated.limit(x, regulated, 0.0) ≈ impacts .* expected_scale
        @test expected_scale * (1 - y + h) ≈ 1 - y
        @test isfinite(SED.protected_pressure_scale(1.0, 0.25, 0.3))

        physical_use = 0.5 .* impacts
        effective_use = physical_use .* expected_scale
        income_state = [effective_use; y]
        inc = incomes(income_state, regulated)
        @test inc.resource ≈ physical_use .* y .* 0.75
        @test inc.wages ≈ (impacts .- physical_use) .* thresholds

        oa = sim(s; t_end=300.0)
        pa_sol = sim(pa; regulation=0.25, start_from_OA=true, t_end=300.0)
        y_oa = oa[s.N+1, end-2]
        initial_scale = SED.protected_pressure_scale(y_oa, 0.25, 0.3)
        @test pa_sol.prob.u0[1:s.N] ≈ oa[1:s.N, end-2] .* initial_scale
        @test SED.SciMLBase.successful_retcode(pa_sol)
    end

    @testset "Protected area explicit two-patch equations" begin
        pa = scenario(s; policy=ProtectedAreaTwoPop(0.3))
        regulated = regulate(pa, 0.25)
        y_u, y_p = 0.4, 0.7
        x = [zeros(s.N); y_u; y_p]
        dx = zeros(length(x))
        SED.dxdt(dx, x, regulated, 0.0)

        migration = 0.3 * (y_p - y_u)
        @test dx[s.N+1] ≈ y_u * (1.0 - y_u) +
                              0.25 / 0.75 * migration
        @test dx[s.N+2] ≈ y_p * (1.0 - y_p) - migration
        @test regulated.cost(x, regulated, 0.0) ≈ thresholds ./ 0.75
        @test regulated.limit(x, regulated, 0.0) ≈ impacts
    end

    @testset "Regulation scan bookkeeping" begin
        economic = scenario(s; policy=EconomicIncentives([:limit], :taxation))
        scan = regulation_scan(economic; m=3, warmstart=:none)

        @test size(scan.sols) == (3, s.N)
        @test scan.oRI == argmax(scan.RI)
    end
end
