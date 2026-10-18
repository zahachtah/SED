module PolicyFigureHelpers
include(joinpath(@__DIR__, "..", "manuscript", "helpers", "policy_scenarios.jl"))
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
