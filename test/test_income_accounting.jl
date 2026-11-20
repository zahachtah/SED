@testset "Explicit income accounting" begin
    s, theta, potential = fixed_scenario()
    use = [0.1, 0.1, 0.0, 0.0]
    y = 0.5
    x = [use; y]

    function check_identity(inc)
        @test inc.resource === inc.resource_revenue
        @test inc.resource_rent ≈ inc.resource_revenue .- inc.opportunity_cost
        @test inc.outside_income ≈ inc.outside_income_0 .- inc.opportunity_cost
        @test inc.total ≈ inc.outside_income_0 .+ inc.resource_rent .+ inc.extra
        @test inc.total ≈ inc.resource_revenue .+ inc.outside_income .+ inc.extra
        @test inc.gross_resource_revenue ≈ inc.resource_revenue .+ inc.state_revenue
    end

    baseline = incomes(x, s)
    check_identity(baseline)
    @test baseline.opportunity_cost ≈ use .* theta
    @test baseline.resource_rent ≈ use .* (y .- theta)
    @test all(iszero, baseline.state_revenue)

    for policy in (ExclusiveUseRights(:top, false), ProtectedArea(0.3),
            ProtectedAreaTwoPop(0.3), EconomicIncentives([:cost, :limit], :multiplicative),
            TradableUseRights(:effort, 0.05, 0.0, false))
        p = regulate(scenario(s; policy), 0.0)
        state = policy isa TradableUseRights || policy isa ProtectedAreaTwoPop ? [x; 0.5] : x
        inc = incomes(state, p)
        check_identity(inc)
        @test inc.total ≈ baseline.total
        @test inc.resource_rent ≈ baseline.resource_rent
    end

    rho, gear = 0.25, 1.5
    royalty = scenario(s; cost=(x, p, t) -> theta ./ (1 - rho),
        income_cost_fun=(x, p, t) -> theta,
        resource_factor_fun=(x, p, t) -> 1 - rho,
        income_state_fun=(x, p, t) -> rho .* x[1:p.N] .* x[p.N+1])
    inc = incomes(x, royalty)
    check_identity(inc)
    @test inc.outside_income_0 ≈ baseline.outside_income_0
    @test inc.state_revenue ≈ rho .* use .* y
    @test inc.gross_resource_revenue ≈ use .* y
    @test inc.total .+ inc.state_revenue ≈ baseline.total

    improved = scenario(s; cost=(x, p, t) -> theta ./ gear,
        limit=(x, p, t) -> gear .* potential)
    inc = incomes([gear .* use; y], improved)
    check_identity(inc)
    @test inc.outside_income_0 ≈ baseline.outside_income_0
    @test inc.opportunity_cost ≈ baseline.opportunity_cost
    @test inc.resource_revenue ≈ gear .* baseline.resource_revenue

    for target in (:effort, :yield)
        p = regulate(scenario(s; policy=TradableUseRights(target, 0.05, 0.0, false)), 0.6)
        physical = target == :effort ? p.R : p.R ./ y
        inc = incomes([physical; y; 0.3], p)
        check_identity(inc)
        @test sum(inc.rights_transfer) ≈ 0.0 atol=1e-14
        @test inc.net_resource_rent ≈ inc.resource_rent .+ inc.rights_transfer
        @test inc.outside_income_0 ≈ baseline.outside_income_0
    end

    pa = regulate(scenario(s; policy=ProtectedArea(0.3)), 0.25)
    scale = SED.protected_pressure_scale(y, 0.25, 0.3)
    inc = incomes([use .* scale; y], pa)
    check_identity(inc)
    @test inc.opportunity_cost ≈ baseline.opportunity_cost
    @test inc.resource_revenue ≈ 0.75 .* baseline.resource_revenue

    custom = scenario(s; income_extra_fun=(x, p, t) -> fill(t, p.N))
    inc = incomes(x, custom; t=0.2)
    check_identity(inc)
    @test inc.other_income == fill(0.2, s.N)
    @test all(iszero, inc.rights_transfer)
    @test inc.resource_rent ≈ baseline.resource_rent

    custom_solution = sim(custom; t_end=1.0)
    timed = incomes(custom_solution)
    @test timed.other_income == fill(custom_solution.t[end], s.N)
    @test incomes(custom_solution; t=0.2).other_income == fill(0.2, s.N)

    scaled = merge(royalty, (; rpk=7.3))
    nd, dimensional = incomes(x, scaled), incomes(x, scaled; dimensional=true)
    for field in (:resource, :resource_revenue, :gross_resource_revenue, :resource_rent,
            :opportunity_cost, :outside_income, :outside_income_0, :rights_transfer,
            :other_income, :state_revenue, :net_resource_rent, :extra, :total)
        @test getproperty(dimensional, field) ≈ 7.3 .* getproperty(nd, field)
    end
    @test dimensional.gini ≈ nd.gini

    scan = regulation_scan(s; m=3, kR=0.0, kRent=1.0, kT=0.0, kG=0.0)
    @test scan.Rent ≈ scan.ToR .- sum(potential .* theta)
    @test scan.Gov ≈ max.(scan.Rent, eps()) ./ 100
    @test scan.oRent == argmax(scan.Rent)
end
