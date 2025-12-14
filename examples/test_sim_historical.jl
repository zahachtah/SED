include("../SED.jl")
using .SED
T = (
    N=200, health=dist(mean=0, sigma=2.0, distribution=Normal,
        dependency_fun="1/(1+exp(-2-independent))"), gender=dist(mean=0.5, distribution=Bernoulli, random=true),

    # $/day scale in the analysis, but here we just need a right-skewed latent.
    parental=dist(min=0.1, max=4.0, distribution=LogNormal),

    # TIME: women ≈ 60% less active fishing time (scaled to [0,1])
    time=dist(min=0.0, max=1.0,
        dependency_fun="clamp( health * (1 - 0.60*gender) * independent , 0, 1)"),

    # EFFICIENCY (CPUE proxy, unitless scaler on [min,max]):
    # women ≈ 0.35 of men; scaled up with parental (capital/gear access)
    efficiency=dist(min=0.015, max=0.20, normalize=false,
        dependency_fun="0.3*( (1-gender) + 0.35*gender ) * parental * independent"),

    # Alternative Income Opportunities (AIO) — keep LogNormal with min/max (no meanlog/sdlog)
    # Slightly higher pull for women via dependency_fun; small scale 0.02*parental matches earlier logic.
    opportunities=dist(min=0.1, max=1.6, distribution=LogNormal,
        dependency_fun="0.02 * parental * (1 + 0.30*gender) * independent"),

    # Ecological scalars for the core (per ha); your engine can read these or you can keep them elsewhere
    r=0.08,       # yr^-1 (within 0.05–0.12)
    K=0.8,        # t/ha  (≈ 800 kg/ha)
    fK=0.50,      # observed fraction of K (B/K)

    # Drivers feeding your Incentive/Impact construction (Σ I = 1 - fK is enforced in core):
    ū=dist(min=-0.1, max=0.1, dependency_fun="time * efficiency"),
    w̃=dist(min=-0.1, max=0.1, dependency_fun="(opportunities ./ (efficiency + 1e-6)) .+ independent"),

    # Adjustment rate
    α=dist(min=0.1, max=0.1, distribution=Uniform))

SED.sample!(T, random=true)

T2 = scenario(T, policy="Tradable Use Rights", policy_target=:effort, market_rate=0.05, buyer_bias=0.0, historical_use_rights=true)

sim(T2, regulation=0.4)