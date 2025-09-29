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
