module IdentityIllustration

using SED

# Illustrative behavioral extension only; monetary income hooks remain baseline.
const PARAMETERS = (
    thresholds=[0.20, 0.65],
    potentials=[0.40, 0.50],
    meaningful_fraction=[0.0, 0.70],
    identity_weight=[0.0, 0.125],
    response_rate=0.10,
)

identity_loss(f, f0, weight) = weight * max(0.0, f0 - f)^2

function fraction_response(y, threshold, beta, f0; upper=false)
    y > threshold && return 1.0
    y == threshold && return upper ? 1.0 : (beta > 0 ? f0 : 0.0)
    beta == 0 && return 0.0
    return clamp(f0 + (y - threshold) / beta, 0.0, f0)
end

function identity_cost(x, p, t)
    fraction = x[1:p.N] ./ p.ū.data
    return p.w̃.data .- 2 .* p.identity_weight ./ p.ū.data .*
        max.(0.0, p.meaningful_fraction .- fraction)
end

function identity_scenario(; strength=1.0)
    a = PARAMETERS
    s = scenario((;
        N=length(a.thresholds),
        α=a.response_rate,
        w̃=dist(data=copy(a.thresholds)),
        ū=dist(data=copy(a.potentials)),
        R=ones(length(a.thresholds)),
        meaningful_fraction=copy(a.meaningful_fraction),
        identity_weight=strength .* a.identity_weight,
        income_cost_fun=(x, p, t) -> p.w̃.data,
    ))
    sample!(s)
    return merge(s, (; cost=identity_cost))
end

function pressure_response(y, s; upper=false)
    beta = 2 .* s.identity_weight ./ s.ū.data
    return sum(s.ū.data .* [
        fraction_response(y, s.w̃.data[i], beta[i], s.meaningful_fraction[i]; upper)
        for i in 1:s.N
    ])
end

end
