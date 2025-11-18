using Test

include(joinpath(@__DIR__, "..", "SED.jl"))
using .SED

@testset "tuple dependent + function" begin
    N = 50
    s = (
        N = N,
        q = dist(min=1/N, max=1/N, normalize=true),
        w = dist(min=0.2, max=0.4),
        K = 2.0,
        w̃ = dist(min=0.0, max=0.0, dependent=(q,w,K),
                 dependency_fun=(indep, dep) -> dep.q .* dep.w ./ dep.K .+ indep),
        s2 = dist(dependent=(q,w̃), dependency_fun=(dep) -> dep.q ./ dep.w̃),
    )
    sample!(s)
    @test length(s.q.data) == N
    @test length(s.w.data) == N
    @test length(s.w̃.data) == N
    @test length(s.s2.data) == N
    @test all(s.w̃ .≈ s.q .* s.w ./ s.K)
    @test all(s.s2 .≈ s.q ./ s.w̃)
end

@testset "policy smoke tests" begin
    N = 50
    base = scenario(base(N=N))
    # Minimal w̃, ū for testing
    w = dist(min=0.2, max=0.4)
    q = dist(min=1/N, max=1/N, normalize=true)
    sample!(w, N); sample!(q, N)
    w̃ = dist(min=0.1, max=1.0, dependency_fun="q .* w .+ independent")
    ū = dist(dependency_fun="q")
    sample!(w̃, N; context=(; base..., w, q))
    sample!(ū, N; context=(; base..., w, q))
    base = scenario(base; w̃, ū)

    # OA
    @test !isnothing(sim(base))
    # EUR
    eur = scenario(base; γ=γ_exclusive_use_rights, regulate=regulate_exclusive_use_rights)
    @test !isnothing(sim(eur; regulation=0.3))
    # TUR
    tur = scenario(base; γ=γ_tradable_use_rights, ϕ=ϕ_tradable_use_rights, regulate=regulate_tradable_use_rights,
        policy="Tradable Use Rights", policy_target=:effort, market_rate=0.05)
    @test !isnothing(sim(tur; regulation=0.3))
    # PA
    pa = scenario(base; γ=γ_protected_area, μ=μ_protected_area, regulate=regulate_protected_area, policy="Protected Area", m=0.3)
    @test !isnothing(sim(pa; regulation=0.3))
    # Econ
    econ = scenario(base; μ=μ_economic_incentive, γ=γ_economic_incentive, regulate=regulate_economic_incentive, policy_target=[:γ,:μ], policy_method=:multiplicative)
    @test !isnothing(sim(econ; regulation=0.2))
    # Dev
    dev = scenario(base; μ=μ_development, γ=γ_development, regulate=regulate_development, μ_value=0.5, γ_value=0.5)
    @test !isnothing(sim(dev; regulation=0.4))
end

@testset "policy hooks" begin
    N = 20
    s0 = scenario(base(N=N))
    # attach a constant extra income per agent
    extra_val = 0.1
    extra_fun(x,p,t) = fill(extra_val, p.N)
    s1 = with_policy(s0; income_extra_fun=extra_fun)
    sol = sim(s1)
    inc = incomes(sol)
    @test isapprox(sum(inc.total) - sum(inc.resource) - sum(inc.wages), N * extra_val; atol=1e-6)

    # resource factor halves resource income when applied
    s2 = with_policy(s1; resource_factor_fun=(x,p,t)->0.5)
    inc1 = incomes(sol) # baseline with no factor
    inc2 = incomes(sol.u[end], s2) # use same terminal state but different p
    @test isapprox(sum(inc2.resource), 0.5 * sum(inc1.resource); atol=1e-6)
end

@testset "policy kits" begin
    N = 30
    s0 = scenario(base(N=N))

    # EUR kit with top selector
    sel = (w̃, n) -> sortperm(w̃, rev=true)[1:n]
    eur = with_policy(s0; exclusive_use_rights_kit(; selector=sel)...)
    @test !isnothing(sim(eur; regulation=0.25))

    # TUR kit
    tur = with_policy(s0; tradable_use_rights_kit(; target=:effort, market_rate=0.05)...)
    @test !isnothing(sim(tur; regulation=0.25))

    # PA kit
    pa = with_policy(s0; protected_area_kit(; m=0.3)...)
    @test !isnothing(sim(pa; regulation=0.25))
end

@testset "tuple dependent + string" begin
    N = 30
    s = (
        N = N,
        q = dist(min=1/N, max=1/N, normalize=true),
        w = dist(min=0.1, max=0.3),
        K = 2.0,
        w̃ = dist(min=0.0, max=0.0, dependent=(q,w,K), dependency_fun="q .* w ./ K .+ sed"),
    )
    sample!(s)
    @test all(s.w̃ .≈ s.q .* s.w ./ s.K)
end

@testset "infer deps from string when dependent omitted" begin
    N = 20
    s = (
        N = N,
        q = dist(min=1/N, max=1/N, normalize=true),
        w = dist(min=0.1, max=0.3),
        K = 2.0,
        w̃ = dist(min=0.0, max=0.0, dependency_fun="q .* w ./ K .+ sed"),
    )
    sample!(s)
    @test all(s.w̃ .≈ s.q .* s.w ./ s.K)
end

@testset "Cycle detection" begin
    N = 10
    cyc = (
        N = N,
        a = dist(dependent=(b,), dependency_fun=(dep)->dep.b .+ 1),
        b = dist(dependent=(a,), dependency_fun=(dep)->dep.a .+ 1),
    )
    @test_throws ArgumentError sample!(cyc)
end
