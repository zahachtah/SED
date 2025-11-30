if !isdefined(Main, :SED)
    error("Load SED first: include(\"SED.jl\"); using .SED")
end

using .SED

Zanzibar = (
    N=36000,
    health=dist(mean=0, sigma=2.0, distribution=Normal, dependency_fun="1/(1+exp(-2-independent))"),
    gender=dist(mean=0.5, distribution=Bernoulli, random=true, unit="[0,1]"),
    parental=dist(mean=1.0, sigma=1.0, distribution=LogNormal, unit="\$/day"),
    time=dist(min=0.0, max=1.0,
        dependency_fun="8.0.*health .* (1 .- gender .* 0.6 .* independent)./24", unit="hours/day"),
    efficiency=dist(min=2.0, max=12.0,
        dependency_fun="health .*(1.0 .+parental/10) .* (1 .- gender .* 0.65) .* independent./K", normalize=false, unit="day^-1"),
    AIO=dist(min=0.3, max=1.6, distribution=LogNormal,
        dependency_fun="(1.0 .+parental/10) .* (1 .- gender .* 0.5) .* independent", unit="\$/day"),
    K=100000,
    p=1,
    r=0.12,
    ū=dist(min=-0.1, max=0.1, dependency_fun="time*efficiency/r"),
    w̃=dist(min=-0.1, max=0.1, dependency_fun="AIO ./ (p.*efficiency.*K)"),
    α=dist(min=0.1, max=0.1, distribution=Uniform)
)

Philippines = (
    N=7_957,
    health=dist(mean=0, sigma=2.0, distribution=Normal, dependency_fun="1/(1+exp(-2-independent))"),#1-max(0.0,independent)
    gender=dist(mean=0.5, distribution=Bernoulli, random=true, unit="share"),
    parental=dist(mean=3.5, sigma=0.6, distribution=LogNormal, unit="SES index"),
    time=dist(min=2.0, max=6.0,
        dependency_fun="health .* (1 .- gender .* 0.5) .* independent", unit="days/week"),
    efficiency=dist(min=5.0, max=13.0,
        dependency_fun="parental .* (1 .- gender .* 0.3) .* independent", normalize=false, unit="kg/day"),
    AIO=dist(min=0.5, max=2.0, distribution=LogNormal,
        dependency_fun="0.05 .* parental .* (1 .- gender .* 0.35) .* independent", unit="index"),
    K=1.25,
    ū=dist(min=0.0, max=6.5,
        dependency_fun="time .* efficiency .* (1 .- gender .* 0.35)"),
    w̃=dist(min=-0.02, max=0.22,
        dependency_fun="(AIO ./ efficiency) .+ independent .* 0.04"),
    α=dist(min=0.1, max=0.1, distribution=Uniform),
)
