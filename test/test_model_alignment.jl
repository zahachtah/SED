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
    end

    @testset "Tradable use rights" begin
        tur = scenario(s; policy=TradableUseRights(:effort, 0.05, 0.0, false))
        regulated = regulate(tur, 0.6)
        price = 0.25
        x = [regulated.R; 0.5; price]

        @test sum(regulated.R) ≈ 0.4
        @test regulated.cost(x, regulated, 0.0) == thresholds .+ price
        @test sum(regulated.income_extra_fun(x, regulated, 0.0)) ≈ 0.0
    end

    @testset "Protected area reduced form" begin
        pa = scenario(s; policy=ProtectedArea(0.3))
        regulated = regulate(pa, 0.25)
        x = [zeros(s.N); 0.5]

        @test regulated.cost(x, regulated, 0.0) ≈ thresholds ./ 0.75
        @test all(regulated.limit(x, regulated, 0.0) .<= impacts)
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
    end

    @testset "Regulation scan bookkeeping" begin
        economic = scenario(s; policy=EconomicIncentives([:limit], :taxation))
        scan = regulation_scan(economic; m=3, warmstart=:none)

        @test size(scan.sols) == (3, s.N)
        @test scan.oRI == argmax(scan.RI)
    end
end
