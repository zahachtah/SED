using Statistics

function regulation_scan(p; m=100, kR=0.5, kT=1.0, kG=-0.2, kE=0.0, kI=0.0)
    r = range(0.0, stop=1.0 - 1.0 / m, length=m)
    RR = zeros(m); WR = zeros(m); TR = zeros(m); ToR = zeros(m)
    GI = zeros(m); EH = zeros(m); RI = zeros(m); Gov = zeros(m)
    oau = zeros(p.N)
    x0 = zeros(p.N + 2); x0[p.N+1] = 1.0
    sols = zeros(m, p.N); incdist = zeros(m, p.N)
    for (j, i) in enumerate(r)
        sol = sim(p, regulation=i, t_end=1000)
        if j == 1; oau = sol[1:p.N, end-1]; end
        inc = incomes(sol.u[end-1], sol.prob.p)
        RR[j] = sum(inc.resource); WR[j] = sum(inc.wages); TR[j] = sum(inc.trade)
        ToR[j] = sum(inc.total); GI[j] = inc.gini; EH[j] = inc.ecological
        regimpact = abs.(oau .- sol[1:p.N, end-1])
        RI[j] = sum(regimpact)
        Gov[j] = sum(inc.resource .^ kR .+ inc.total .^ kT .+ inc.gini .^ kG .+ inc.ecological .^ kE .+ regimpact .^ kI)
        sols[j, :] = sol.u[end-1][1:p.N] ./ p.ū
        incdist[j, :] = inc.total
    end
    oRR = argmax(RR); oWR = argmax(WR); oTR = argmax(TR); oToR = argmax(ToR)
    oGI = argmin(GI); oEH = argmax(EH); oRI = argmax(EH); oGov = argmax(Gov)
    return (; RR, WR, TR, ToR, GI, EH, RI, Gov=Gov ./ 100.0, r, oRR, oWR, oTR, oToR, oGI, oEH, oRI, oGov, sols, incdist)
end

function Γ(y, p; x=zeros(p.N + 1), t=0.0)
    x[p.N+1] = y
    γ = p.γ(x, p, t)
    id = sortperm(γ)
    f = sum(γ[id] .< y) / p.N
end

function Φ(y, p; t=0.0)
    x = zeros(p.N + 1)
    x[end] = y
    γ = p.γ(x, p, t)
    id = sortperm(γ)
    μ = p.μ(x, p, t)
    cu = cumsum(μ[id])
    f = sum(cu .< (1.0 - y))
    if f == 0
        f = (1.0 - y) / μ[id[1]]
    elseif f < p.N
        f = f + ((1 - y) - cu[f]) / μ[id[f+1]]
    end
    return f / p.N
end

function incomes(x, p; summarize=false, dimensional::Bool=false)
    # unpack state and parameters
    y = x[p.N+1]
    u = x[1:p.N]

    # resource income with optional policy-provided factor
    rf = hasproperty(p, :resource_factor_fun) ? p.resource_factor_fun(x, p, 0.0) : 1.0
    resource_factor = rf isa Number ? fill(rf, p.N) : rf
    resource_nd = u .* y .* resource_factor

    # wages based on μ and γ
    μ = p.μ(x, p, 0.0)
    γw = p.γ(x, p, 0.0)
    wages_nd = (μ .- u) .* γw
    wages_0_nd = μ .* γw

    # optional additional income component provided by policy
    extra_nd = hasproperty(p, :income_extra_fun) ? p.income_extra_fun(x, p, 0.0) : zeros(p.N)

    total_nd = resource_nd .+ wages_nd .+ extra_nd
    g = gini(total_nd)
    ecological = y

    if dimensional
        scale = p.rpk
        resource = resource_nd .* scale
        wages = wages_nd .* scale
        wages_0 = wages_0_nd .* scale
        extra = extra_nd .* scale
        total = total_nd .* scale
    else
        resource, wages, wages_0, extra, total = resource_nd, wages_nd, wages_0_nd, extra_nd, total_nd
    end

    out = (; resource, wages, extra, trade=extra, total, gini=g, ecological, wages_0)
    return summarize ? merge(out, (; g=g, ecological=ecological)) : out
end

incomes(sol::ODESolution) = incomes(sol.u[end], sol.prob.p)

function gini(x)
    sum([abs(x[i] - x[j]) for i in 1:length(x), j in 1:length(x)]) / (2 * length(x) * sum(x))
end
