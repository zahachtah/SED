using SED
using Test
using Distributions

@testset "SEDist Properties and Display" begin
    # 1. Uniform
    u = dist(distribution=Uniform, mean=0.5, sigma=0.1)
    println("Uniform SEDist:")
    display(u)
    println("Mean: ", u.mean)
    println("Sigma: ", u.sigma)

    @test u.mean ≈ 0.5
    # sigma passed to dist(Uniform) is width. std is width/sqrt(12).
    @test u.sigma ≈ 0.1 / sqrt(12)

    # 2. LogNormal
    l = dist(distribution=LogNormal, mean=0.0, sigma=1.0)
    println("\nLogNormal SEDist:")
    display(l)
    println("Mean (statistical): ", l.mean)
    println("Sigma (statistical): ", l.sigma)

    # Note: For LogNormal, mean(d) is NOT the mu parameter.
    # mu=0, sigma=1 => mean = exp(0 + 0.5) = 1.648...
    @test l.mean ≈ exp(0.5)

    # 3. Dependency
    dep = SED.@dependent (q) -> 0.5 .* q .+ independent
    d = dist(dependency=dep,
        distribution=Normal, mean=0, sigma=1)
    println("\nDependent SEDist:")
    display(d)
    println("Dependency: ", d.dependency)
end
