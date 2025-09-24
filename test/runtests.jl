using Test

include(joinpath(@__DIR__, "..", "SEDist.jl"))
using .SEDist

@testset "tuple dependent + function" begin
    N = 50
    s = (
        N = N,
        q = sed(min=1/N, max=1/N, normalize=true),
        w = sed(min=0.2, max=0.4),
        K = 2.0,
        w̃ = sed(min=0.0, max=0.0, dependent=(q,w,K),
                 dependency_fun=(indep, dep) -> dep.q .* dep.w ./ dep.K .+ indep),
        s2 = sed(dependent=(q,w̃), dependency_fun=(dep) -> dep.q ./ dep.w̃),
    )
    dist!(s)
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
        q = sed(min=1/N, max=1/N, normalize=true),
        w = sed(min=0.1, max=0.3),
        K = 2.0,
        w̃ = sed(min=0.0, max=0.0, dependent=(q,w,K), dependency_fun="q .* w ./ K .+ sed"),
    )
    dist!(s)
    @test all(s.w̃ .≈ s.q .* s.w ./ s.K)
end

@testset "Cycle detection" begin
    N = 10
    cyc = (
        N = N,
        a = sed(dependent=(b,), dependency_fun=(dep)->dep.b .+ 1),
        b = sed(dependent=(a,), dependency_fun=(dep)->dep.a .+ 1),
    )
    @test_throws ArgumentError dist!(cyc)
end
