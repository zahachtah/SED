using SED
using Test
using Statistics

@testset "Raw NamedTuple Support" begin
    # Define T as a raw NamedTuple (no master functions)
    T = (
        N=10,
        α=0.1,
        w̃=dist(min=0.1, max=1.0, distribution=LogNormal),
        ū=dist(mean=1.0, normalize=true),
        R=ones(10)
    )

    # Apply policy
    s1 = with_policy(T; tradable_use_rights_kit(target=:effort, buyer_bias=1.0)...)

    # Check if master functions are present
    @test hasproperty(s1, :γ)
    @test hasproperty(s1, :μ)
    @test hasproperty(s1, :ϕ)

    # Run simulation
    SED.sample!(s1)
    sol = sim(s1, regulation=0.5)

    @test Symbol(sol.retcode) == :Success
    println("Raw NamedTuple verification passed.")
end
