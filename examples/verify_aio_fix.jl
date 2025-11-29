using SED
using Test
using Statistics
using Distributions

@testset "AIO Constant Data Fix" begin
    # Reproduce user's AIO definition
    # We need parental and gender for the dependency
    # Mock them as simple SEDists
    parental = dist(min=0.1, max=1.0, distribution=LogNormal)
    gender = dist(mean=0.5, distribution=Bernoulli, random=true)

    # Sample them first
    SED.sample!(parental, 100)
    SED.sample!(gender, 100)

    # Context for dependency
    context = (parental=parental.data, gender=gender.data)

    # AIO definition
    # dependency_fun="0.02*parental*(1-gender*0.3)*independent"
    # min=0.1, max=1.6
    # Before fix: data was clamped to 0.1 (because result is ~0.004)
    # After fix: data should be ~0.004

    AIO = dist(min=0.1, max=1.6, distribution=LogNormal, dependency_fun="0.02*parental*(1-gender*0.3)*independent")

    # Sample AIO
    # We need to pass context manually or use sample!(context)
    # But AIO is standalone here.
    # We can use sample!(AIO, 100, context=context)

    SED.sample!(AIO, 100, context=context)

    println("AIO Mean: ", mean(AIO.data))
    println("AIO Min: ", minimum(AIO.data))
    println("AIO Max: ", maximum(AIO.data))

    # Verify it is NOT constant 0.1
    @test mean(AIO.data) < 0.1
    @test std(AIO.data) > 0.0

    println("AIO verification passed.")
end
