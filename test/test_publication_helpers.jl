module PolicyFigureHelpers
include(joinpath(@__DIR__, "..", "manuscript", "figure4.jl"))
end

module SupplementaryPolicyHelpers
include(joinpath(@__DIR__, "..", "SupplementaryMaterial", "scripts", "generate_policy_explainers.jl"))
end

module SupplementaryConstructionHelpers
include(joinpath(@__DIR__, "..", "SupplementaryMaterial", "scripts", "generate_figures.jl"))
end

@testset "Supplementary pressure construction includes the marginal actor" begin
    h = SupplementaryConstructionHelpers
    fig = h.with_theme(h.paper_theme()) do
        h.attractor_construction_figure(; save_output=false)
    end
    ax = only(filter(x -> x isa h.Axis && startswith(x.title[], "3."), fig.content))
    curve = only(filter(x -> x isa h.Makie.Lines, ax.scene.plots))[1][]
    balance = last(filter(x -> x isa h.Makie.Scatter, ax.scene.plots))[1][][1]
    @test balance[1] ≈ 0.55 atol=1e-5
    @test balance[2] ≈ 0.58 atol=1e-5
    left = findlast(point -> point[1] <= balance[1], curve)
    fraction = (balance[1] - curve[left][1]) / (curve[left + 1][1] - curve[left][1])
    interpolated = curve[left] + fraction * (curve[left + 1] - curve[left])
    @test interpolated ≈ balance atol=1e-6
end

@testset "Supplementary policy income uses the same accounting" begin
    h = SupplementaryPolicyHelpers.PolicyExplainers
    data = h.build_policy_solutions()
    baseline = incomes(h.steady_state(data.oa), data.oa.prob.p)
    royalty = incomes(h.steady_state(data.royalty), data.royalty.prob.p)
    gear = incomes(h.steady_state(data.gear), data.gear.prob.p)
    @test royalty.outside_income_0 ≈ baseline.outside_income_0
    @test gear.outside_income_0 ≈ baseline.outside_income_0
    x = h.steady_state(data.royalty)
    @test royalty.state_revenue ≈ data.royalty_rate .* x[1:data.base_s.N] .* x[data.base_s.N+1]
    @test data.gear.u[1][1:data.base_s.N] ≈ data.gear_factor .* h.steady_state(data.oa)[1:data.base_s.N]
    for sol in (data.oa, data.exclusive_low, data.exclusive_high, data.tradable_equal,
            data.tradable_historical, data.protected, data.royalty, data.gear)
        inc = incomes(h.steady_state(sol), sol.prob.p)
        @test inc.total ≈ inc.outside_income_0 .+ inc.resource_rent .+ inc.extra
    end
    transfers = [incomes(h.steady_state(sol), sol.prob.p).trade
        for sol in (data.tradable_equal, data.tradable_historical)]
    common_limit = 1.15 * maximum(maximum(abs, values) for values in transfers)
    fig = h.Figure(size=(600, 500))
    equal = h.transfer_axis!(fig[1, 1], data.tradable_equal, "Equal", data.thresholds;
        shared_limit=common_limit)
    historical = h.transfer_axis!(fig[2, 1], data.tradable_historical, "Historical", data.thresholds;
        shared_limit=common_limit)
    @test equal.limits[] == historical.limits[]
end

@testset "Income insets preserve external panel titles" begin
    h = PolicyFigureHelpers
    fig = h.Figure(size=(400, 200))
    ax = h.Axis(fig[1, 1], title="External heading")
    panel_title = h.Label(fig[0, 1], "D) Income distribution at the attractor")
    heading = h.income_panel_heading!(ax, "Scenario", "Revenue 0.25 · Total 0.45 · Gini 0.10";
        color=:black, summary_color=:gray, fontsize=12)
    @test ax.title[] == ""
    @test heading.space[] == :relative
    h.income_panel_heading!(ax, "", "Rev. 0.25 · Total 0.45 · Gini 0.10";
        color=:black, summary_color=:gray, fontsize=12)
    @test panel_title.text[] == "D) Income distribution at the attractor"
    @test ax.title[] == ""
end

@testset "Arc helper supports one explicit arrowhead" begin
    h = PolicyFigureHelpers
    fig = h.Figure(size=(160, 160))
    ax = h.Axis(fig[1, 1])
    before = length(ax.scene.plots)
    arrow_arc_deg!(ax, h.Point2f(0.5, 0.5), 0.2, 0, 90;
        endarrow=false, space=:data)
    @test length(ax.scene.plots) == before + 1
    before = length(ax.scene.plots)
    arrow_arc_deg!(ax, h.Point2f(0.5, 0.5), 0.2, 0, 90; space=:data)
    @test length(ax.scene.plots) == before + 2
end

@testset "Policy arrows use native Makie paths and proportional heads" begin
    h = PolicyFigureHelpers
    xs = collect(range(0.0, 1.0; length=201))
    source = 0.7 .- xs
    destination = 2.2 .- 3.5 .* xs
    @test h.curve_point(xs, source, 0.10) ≈ h.Point2f(0.10, 0.60)
    @test h.curve_point(xs, destination, 0.40) ≈ h.Point2f(0.40, 0.80)
    @test_throws ErrorException h.curve_point(xs, fill(NaN, length(xs)), 0.1)
    fig = h.Figure(size=(220, 220))
    ax = h.Axis(fig[1, 1])
    before = length(ax.scene.plots)
    straight = h.draw_curve_transfer_arrow!(ax, xs, source, xs, destination, 0.1, 0.4, :black)
    @test length(ax.scene.plots) == before + 1
    @test straight isa h.Makie.Annotation
    @test straight.path[] isa h.Makie.Ann.Paths.Line
    @test straight.style[].head isa h.Makie.Ann.Arrows.Head
    @test straight.style[].head.length ≈ 4straight.linewidth[]
    @test straight.style[].tail === nothing
    curved = h.draw_curve_transfer_arrow!(ax, xs, source, xs, destination, 0.1, 0.4, :green;
        bend=0.38)
    @test curved.path[] isa h.Makie.Ann.Paths.Arc
    @test curved.path[].height == 0.38
    @test curved.linewidth[] == straight.linewidth[]
    @test curved.style[].head == straight.style[].head
    @test_throws ArgumentError h.draw_curve_transfer_arrow!(ax, xs, source, xs, source, 0.1, 0.1, :black)

    before = length(ax.scene.plots)
    SED._rent_reallocation_arrow!(ax, [-0.2, 0.0, 0.0], [0.0, 0.0, 0.2],
        [0.1, 0.2, 0.3], [0.3, 0.0, 0.0], :gray)
    @test length(ax.scene.plots) == before + 1
    rent = last(ax.scene.plots)
    @test rent isa h.Makie.Annotation
    @test rent.path[].height < 0
    @test rent.style[].head.length ≈ 4rent.linewidth[]
end

@testset "Figure 4 income incidence and economic accounting" begin
    h = PolicyFigureHelpers
    rows, oa = h.policy_rows()
    x0 = h.steady_state(oa)
    theta0 = h.distdata(oa.prob.p.w̃)
    potential0 = h.distdata(oa.prob.p.ū)
    baseline = incomes(x0, oa.prob.p)

    lo, hi = h.shared_income_limits(rows)
    @test lo < 0 < hi
    @test all(row -> all(v -> begin
        a, b = h.income_panel_limits(v.sol)
        lo <= a < b <= hi
    end, row.variants), rows)

    unchanged = h.income_changes(oa, oa)
    @test all(iszero, unchanged.delta)
    @test unchanged.unchanged_share == 1
    @test unchanged.gini_change == 0

    for row in rows, variant in row.variants
        change = h.income_changes(variant.sol, oa)
        current = incomes(h.steady_state(variant.sol), variant.sol.prob.p)
        @test change.order == sortperm(theta0)
        @test change.delta ≈ current.total .- baseline.total
        @test change.total_change ≈ sum(current.total) - sum(baseline.total)
        @test change.gini_change ≈ gini(current.total) - gini(baseline.total)
        @test change.winner_share + change.loser_share + change.unchanged_share ≈ 1
    end

    royalty = rows[4].variants[1].sol
    p = royalty.prob.p
    x = h.steady_state(royalty)
    use, stock = x[1:p.N], x[p.N+1]
    rho = p.royalty_rate
    inc = incomes(x, p)
    @test inc.wages ≈ (potential0 .- use) .* theta0
    @test inc.wages_0 ≈ potential0 .* theta0
    @test inc.resource ≈ (1 - rho) .* use .* stock
    @test h.public_revenue(royalty) ≈ rho * stock * sum(use)
    @test sum(inc.total) + h.public_revenue(royalty) ≈
        stock * sum(use) + sum((potential0 .- use) .* theta0)
    # The combined payoff displayed in Figure 4 uses the original common numeraire.
    @test inc.total ≈ (1 - rho) .* use .* stock .+ (potential0 .- use) .* theta0
    @test h.income_changes(royalty, oa).winner_share == 0
    @test abs(stock - 0.5) < 3e-4

    zero_p = p.regulate(p, 0.0)
    @test incomes(x0, zero_p).total ≈ baseline.total

    gear = rows[4].variants[2].sol
    pg = gear.prob.p
    xg = h.steady_state(gear)
    @test pg.cost(xg, pg, 0.0) .* 1.5 ≈ theta0
    @test pg.limit(xg, pg, 0.0) ≈ 1.5 .* potential0
    @test incomes(xg, pg).wages_0 ≈ baseline.wages_0
    ug, yg = xg[1:pg.N], xg[pg.N+1]
    @test incomes(xg, pg).total ≈ ug .* yg .+ (1.5 .* potential0 .- ug) .* (theta0 ./ 1.5)
    @test gear.u[1][1:pg.N] ≈ 1.5 .* x0[1:pg.N]
    @test gear.u[1][pg.N+1] ≈ x0[pg.N+1]
    zero_gear = pg.regulate(pg, 0.0)
    @test zero_gear.cost(x0, zero_gear, 0.0) ≈ theta0
    @test zero_gear.limit(x0, zero_gear, 0.0) ≈ potential0
    @test incomes(x0, zero_gear).total ≈ baseline.total
end

@testset "Publication curves use the package implementation" begin
    h = PolicyFigureHelpers
    population, _, _ = h.figure_population(; N=32)
    oa = sim(population; t_end=1000.0)
    managed = sim(scenario(population; policy=TradableUseRights(:effort, 0.05, 0.0, false));
        regulation=0.5, start_from_OA=true, t_end=1000.0)

    for sol in (oa, managed)
        y, participation, required = h.curves_for(sol; n=81)
        state, time = h.steady_state(sol), h.steady_time(sol)
        @test participation == [Γ(level, sol.prob.p; x=state, t=time) for level in y]
        @test isequal(required, [Φ(level, sol.prob.p; x=state, t=time) for level in y])
    end
    @test h.same_series([NaN, 0.2], [NaN, 0.2])
    @test !h.same_series([NaN, 0.2], [0.0, 0.2])
end
