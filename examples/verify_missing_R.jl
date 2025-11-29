using SED
using Test
using Statistics

@testset "Missing R Verification" begin
    # Define T as a raw NamedTuple without R
    # Using simple distributions for speed
    T = (
        N=10,
        α=0.1,
        w̃=dist(min=0.1, max=1.0, distribution=LogNormal),
        ū=dist(mean=1.0, normalize=true)
        # R is missing!
    )

    # Apply policy with historical_use_rights=true
    # We use scenario(T) to get master functions, but R is still missing from T
    s1 = with_policy(scenario(T); tradable_use_rights_kit(target=:effort, buyer_bias=1.0, historical_use_rights=true)...)

    # Run simulation
    # This triggered the error because OA solve tried to use the policy which needed R
    SED.sample!(s1)
    sol = sim(s1, regulation=0.5)

    @test Symbol(sol.retcode) == :Success
    println("Missing R verification passed.")
end
