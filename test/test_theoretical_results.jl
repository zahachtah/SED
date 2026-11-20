using Random

include(joinpath(@__DIR__, "..", "SupplementaryMaterial", "scripts", "identity_extension.jl"))

function theoretical_population(thresholds, potentials)
    s = scenario((; N=length(thresholds), α=0.10,
        w̃=dist(data=copy(thresholds)), ū=dist(data=copy(potentials)),
        R=ones(length(thresholds))))
    sample!(s)
    return s
end

# Independent generalized crossing, including jumps at marginal actors.
function pressure_crossing(thresholds, potentials)
    lower, upper = 0.0, 1.0
    for _ in 1:60
        mid = (lower + upper) / 2
        pressure = sum(potentials[thresholds .<= mid])
        if pressure < 1 - mid
            lower = mid
        else
            upper = mid
        end
    end
    return (lower + upper) / 2
end

@testset "Distribution-independent ordering results" begin
    rng = MersenneTwister(207)
    for _ in 1:80
        theta = 0.03 .+ 1.15 .* rand(rng, 9)
        potential = 0.02 .+ rand(rng, 9)
        potential .*= 0.90 / sum(potential)
        y0 = pressure_crossing(theta, potential)
        @test pressure_crossing(theta .+ 0.2, potential) >= y0 - 1e-12
        @test pressure_crossing(1.4 .* theta, potential) >= y0 - 1e-12
        @test pressure_crossing(theta, 1.3 .* potential) <= y0 + 1e-12
        ordered_theta = sort(theta)
        low_first, high_first = sort(potential; rev=true), sort(potential)
        @test all(cumsum(low_first) .>= cumsum(high_first) .- 1e-12)
        @test pressure_crossing(ordered_theta, low_first) <=
            pressure_crossing(ordered_theta, high_first) + 1e-12
    end

    theta = [0.20, 0.60]
    for (potential, exact_y, exact_u) in (
            ([0.20, 0.70], 0.60, [0.20, 0.20]),
            ([0.70, 0.20], 0.30, [0.70, 0.0]))
        s = theoretical_population(theta, potential)
        @test pressure_crossing(theta, potential) ≈ exact_y
        pstar = sum(exact_u ./ potential) / 2
        @test Φ(exact_y, s) ≈ pstar
        @test Γ(exact_y, s) <= pstar <= count(theta .<= exact_y) / 2
        for (u0, y0) in ((zeros(2), 1.0), (potential, 0.15))
            sol = sim(s; u0, y0, t_end=4000.0)
            @test sol.u[end][3] ≈ exact_y atol=0.002
            @test sol.u[end][1:2] ≈ exact_u atol=0.002
        end
    end

    # Endpoints above the plotted threshold range and tied actors are included.
    @test pressure_crossing([0.2, 1.2], [0.7, 0.2]) ≈ 0.3
    @test pressure_crossing([0.4, 0.4], [0.7, 0.2]) ≈ 0.4
end

@testset "Illustrative identity extension" begin
    h = IdentityIllustration
    baseline = h.identity_scenario(; strength=0.0)
    extended = h.identity_scenario()
    theta, potential = baseline.w̃.data, baseline.ū.data
    @test h.identity_loss(0.7, 0.7, 0.125) == 0.0
    @test h.identity_loss(0.0, 0.7, 0.125) ≈ 0.06125
    @test h.fraction_response(0.45, 0.65, 0.5, 0.7) ≈ 0.3
    @test h.fraction_response(0.20, 0.65, 0.5, 0.7) == 0.0
    @test h.fraction_response(0.80, 0.65, 0.5, 0.7) == 1.0
    @test h.fraction_response(0.65, 0.65, 0.5, 0.7) == 0.7
    @test h.fraction_response(0.65, 0.65, 0.5, 0.7; upper=true) == 1.0
    @test h.pressure_response(0.60, baseline) ≈ 0.40
    @test h.pressure_response(0.45, extended) ≈ 0.55

    for fraction in (0.2, 0.6, 0.8)
        u, y = potential[2] * fraction, 0.45
        value(v) = y * v + (potential[2] - v) * theta[2] -
            h.identity_loss(v / potential[2], 0.7, 0.125)
        derivative = (value(u + 1e-6) - value(u - 1e-6)) / 2e-6
        state = [0.2, u, y]
        @test derivative ≈ y - extended.cost(state, extended, 0.0)[2] atol=1e-9
        # A nonmonetary loss must not silently change earnings or rent at a state.
        @test incomes(state, extended).total ≈ incomes(state, baseline).total
        @test incomes(state, extended).resource_rent ≈ incomes(state, baseline).resource_rent
    end
    oa = sim(baseline; t_end=4000.0)
    sol = sim(extended; u0=oa.u[end][1:2], y0=oa.u[end][3], t_end=4000.0)
    @test oa.u[end][3] ≈ 0.60 atol=0.002
    @test sol.u[end][3] ≈ 0.45 atol=0.002
    @test sol.u[end][1:2] ≈ [0.4, 0.15] atol=0.002
    @test sol.u[1] ≈ oa.u[end]
end
