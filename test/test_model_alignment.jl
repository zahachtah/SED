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
        @test Φ(0.0, s) ≈ 3 / 4
        @test Φ(1.0, s) == 0.0
    end

    @testset "Open-access dynamics and bounds" begin
        sol = sim(s; t_end=300.0)
        x = sol.u[end]
        @test all((0.0 .<= x[1:s.N]) .& (x[1:s.N] .<= impacts))
        @test 0.0 <= x[s.N+1] <= 1.0 + 1e-8
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
        @test all(regulated.limit(x, regulated, 0.0) .<= impacts)

        y = 0.5
        expected_y_p = ((1 - 0.3) + sqrt((1 - 0.3)^2 + 4 * 0.3 * y)) / 2
        @test SED.yₚ(y, 0.25, 0.3) ≈ expected_y_p
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
        expected_spillover = (0.25 / 0.75) * migration / y_u
        @test regulated.limit(x, regulated, 0.0) ≈
              impacts ./ (1 + expected_spillover)
    end

    @testset "Regulation scan bookkeeping" begin
        economic = scenario(s; policy=EconomicIncentives([:limit], :taxation))
        scan = regulation_scan(economic; m=3, warmstart=:none)

        @test size(scan.sols) == (3, s.N)
        @test scan.oRI == argmax(scan.RI)
    end
end
