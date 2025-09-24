using Test

include(joinpath(@__DIR__, "..", "SEDist.jl"))
using .SEDist
using .SEDist: @dep

@testset "Context + @dep basics" begin
    N = 50
    ctx = Context((
        q = sed(min=1/N, max=1/N, normalize=true),
        w = sed(min=0.2, max=0.4),
        K = 2.0,
        w̃ = @dep (q, w, K) -> q .* w ./ K,
        s = @dep (q, w̃)    -> q ./ w̃,
    ))
    dist!(ctx; N=N)

    @test length(ctx[:q]) == N
    @test length(ctx[:w]) == N
    @test length(ctx[:w̃]) == N
    @test length(ctx[:s]) == N

    # Scalar broadcasting
    @test all(ctx[:w̃] .≈ ctx[:q] .* ctx[:w] ./ 2.0)
end

@testset "Inline sed in @dep" begin
    N = 30
    ctx = Context((
        q = sed(min=1/N, max=1/N, normalize=true),
        w = sed(min=0.1, max=0.3),
        w̃ = @dep (q, w) -> q .* w .+ sed(min=0.0, max=0.0), # zero-width noise for determinism
    ))
    dist!(ctx; N=N)
    @test all(ctx[:w̃] .≈ ctx[:q] .* ctx[:w])
end

@testset "Cycle detection" begin
    N = 10
    cyc = Context((
        a = @dep (b) -> b .+ 1,
        b = @dep (a) -> a .+ 1,
    ))
    @test_throws ArgumentError dist!(cyc; N=N)
end
