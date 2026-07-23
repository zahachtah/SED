using Test
using Statistics

@testset "SEDist Refactor" begin

    @testset "Parametric Sources" begin
        # Uniform
        d = SED.dist(min=0, max=10, distribution=Uniform)
        SED.sample!(d, 100; random=true)
        @test length(d) == 100
        @test minimum(d) >= 0
        @test maximum(d) <= 10

        # Normal
        d = SED.dist(mean=5, sigma=2, distribution=Normal)
        SED.sample!(d, 1000; random=true)
        @test abs(mean(d) - 5) < 0.5
        @test abs(std(d) - 2) < 0.5

        # LogNormal (Min/Max)
        d = SED.dist(min=1, max=10, distribution=LogNormal)
        SED.sample!(d, 10000; random=true)
        # Check if 1% and 99% quantiles are close to 1 and 10
        @test abs(quantile(d.data, 0.01) - 1) < 0.5
        @test abs(quantile(d.data, 0.99) - 10) < 1.0
    end

    @testset "Dependencies" begin
        # Simple dependency
        ctx = (
            N=10,
            q=SED.dist(min=1, max=1, distribution=Uniform), # Constant 1
            w=SED.dist(min=2, max=2, distribution=Uniform), # Constant 2
            res=SED.dist(dependency_fun="q + w")
        )
        SED.sample!(ctx)
        @test all(ctx.res .≈ 3.0)

        # With independent (Uniform default)
        ctx2 = (
            N=100,
            q=SED.dist(min=1, max=1, distribution=Uniform),
            res=SED.dist(dependency_fun="q + independent") # 1 + U(0,1)
        )
        SED.sample!(ctx2)
        @test minimum(ctx2.res) >= 1.0
        @test maximum(ctx2.res) <= 2.0

        # With independent (Explicit Source)
        ctx3 = (
            N=100,
            q=SED.dist(min=1, max=1, distribution=Uniform),
            res=SED.dist(mean=0, sigma=1, distribution=Normal, dependency_fun="q + independent") # 1 + N(0,1)
        )
        SED.sample!(ctx3)
        # `mean(::SEDist)` describes the independent source; dependencies are
        # reflected in the realized data.
        @test abs(mean(ctx3.res.data) - 1.0) < 0.2
    end

    @testset "Random vs Quantiles" begin
        d = SED.dist(min=0, max=1, distribution=Uniform)

        # Random
        SED.sample!(d, 100; random=true)
        @test std(diff(sort(d.data))) > 1e-6 # Not perfectly spaced

        # Quantiles (random=false)
        SED.sample!(d, 100; random=false)
        sorted = sort(d.data)
        diffs = diff(sorted)
        @test std(diffs) < 1e-6 # Perfectly spaced
        @test sorted[1] ≈ 1 / 101
        @test sorted[end] ≈ 1 - 1 / 101
    end

    @testset "Dependency Order" begin
        # a -> b -> c
        ctx = (
            N=10,
            c=SED.dist(dependency_fun="b + 1"),
            a=SED.dist(min=1, max=1, distribution=Uniform),
            b=SED.dist(dependency_fun="a * 2")
        )
        SED.sample!(ctx)
        @test all(ctx.a .≈ 1.0)
        @test all(ctx.b .≈ 2.0)
        @test all(ctx.c .≈ 3.0)
    end

    @testset "Dependent Macro" begin
        # Basic
        ctx = (
            N=10,
            q=SED.dist(min=1, max=1, distribution=Uniform),
            w=SED.dist(min=2, max=2, distribution=Uniform),
            res=SED.dist(dependency=SED.@dependent (q, w) -> q .+ w)
        )
        SED.sample!(ctx)
        @test all(ctx.res .≈ 3.0)

        # With independent
        ctx2 = (
            N=100,
            q=SED.dist(min=1, max=1, distribution=Uniform),
            res=SED.dist(dependency=SED.@dependent (q) -> q .+ independent)
        )
        SED.sample!(ctx2)
        @test minimum(ctx2.res) >= 1.0
        @test maximum(ctx2.res) <= 2.0

        # With sed alias
        ctx3 = (
            N=100,
            q=SED.dist(min=1, max=1, distribution=Uniform),
            res=SED.dist(dependency=SED.@dependent (q) -> q .+ sed)
        )
        SED.sample!(ctx3)
        @test minimum(ctx3.res) >= 1.0
        @test maximum(ctx3.res) <= 2.0
    end

end
