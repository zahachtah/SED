using SED
using Test
using Statistics

@testset "Historical Use Rights Verification" begin
    # 1. Default (Equal Shares)
    s_default = with_policy(high_impact(); tradable_use_rights_kit(target=:effort, historical_use_rights=false)...)
    SED.sample!(s_default)
    # Apply regulation to trigger R calculation
    s_default_reg = s_default.regulate(s_default, 0.5)

    # R should be uniform
    @test std(s_default_reg.R) ≈ 0.0 atol = 1e-10
    println("Default R std: ", std(s_default_reg.R))

    # 2. Historical Use Rights
    s_hist = with_policy(high_impact(); tradable_use_rights_kit(target=:effort, historical_use_rights=true)...)
    SED.sample!(s_hist)
    # Apply regulation
    s_hist_reg = s_hist.regulate(s_hist, 0.5)

    # R should be non-uniform (proportional to historical usage)
    # Since w̃ is LogNormal, usage should vary.
    @test std(s_hist_reg.R) > 0.0
    println("Historical R std: ", std(s_hist_reg.R))

    println("Historical Use Rights verification passed.")
end
