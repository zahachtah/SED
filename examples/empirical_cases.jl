include("../SED.jl")
using .SED
using CairoMakie
using StatsBase: ecdf, mean, median

"""
    ZANZIBAR

Unguja / Pemba empirical ranges with gender and health modifiers embedded via string dependencies.
"""
Z = (
    N=200,
    health=dist(mean=0, sigma=2.0, distribution=Normal, dependency_fun="1/(1+exp(-2-independent))"),#1-max(0.0,independent)
    gender=dist(mean=0.5, distribution=Bernoulli, random=true),
    parental=dist(mean=1.0, sigma=1.0, distribution=LogNormal),
    time=dist(dependency_fun="health*(1-gender*0.5)*independent", min=0, max=1),

    efficiency=dist(min=0.015, max=0.2, dependency_fun="1/10000*parental*(1-gender*0.2)*independent", normalize=false),

    price=dist(mean=1.8,sigma=0.5, distribution=Normal, dependency_fun="independent*(1-gender*0.5)"),
 
    aio=dist(min=0.1, max=1.6, distribution=LogNormal, dependency_fun="0.02*parental*(1-gender*0.5)*independent"),
    K=800.0,
    r=0.00022,
    ū=dist(min=-0.1, max=0.1, dependency_fun="time*efficiency/r"),
    w̃=dist(min=-0.1, max=0.1, dependency_fun="(aio ./ (efficiency.*K.*price)) .+ independent"),
    α=dist(min=0.1, max=0.1, distribution=Uniform) #fill(0.1,100)#
)


sample!(Z, random=true)

labels = ["Gender", "Health", "Parental \$", "Time", "CPUE","Price (\$)", "AIO (\$)", "Impact", "Incentive"]
vars = [:gender, :health, :parental,  :time, :efficiency, :price,:aio, :ū, :w̃]

fig = SED.distribution_plot(
    Z, vars; labels=labels,
    corr=:spearman,
    cellsize=(90, 90), markersize=3,
    cmap=:coolwarm, reverse_cmap=true,
    dep_range=(1:4, 6:9),   # placed at fig[1:4, 5:8]
)

SED.phase_plot!(Axis(fig[5:6,8:9]),SED.sim(SED.scenario(Z)))
fig
"""
    PHILIPPINES

Concepcion empirical ranges (reef + seagrass) with the same dependency style as ZANZIBAR.
"""
P = (
    N = 200,
    gender = dist(mean=0.5, distribution=Bernoulli, random=true),  # 1 = women
    health = dist(mean=0.0, sigma=0.35, distribution=Normal, random=true),
    parental = dist(min=exp(0.2), max=exp(1.2), distribution=LogNormal, random=true),

    price = dist(min=1.10, max=3.60, distribution=Uniform, random=true,
        dependency_fun="clamp.(independent .* (1 .- 0.35 .* gender), 0.6, 3.6)"),
    time = dist(min=3.0, max=6.0, distribution=Uniform, random=true,
        dependency_fun="clamp.(independent .* (1 .- 0.5 .* gender) .* (1 .+ 0.1 .* health), 1.5, 6.0)"),
    efficiency = dist(min=5.0, max=13.0, distribution=Uniform, random=true,
        dependency_fun="clamp.(independent .* (0.7 .+ 0.3 .* (1 .- gender)) .* (1 .+ 0.1 .* health), 3.0, 13.0)"),
    aio = dist(min=0.1, max=0.35, distribution=Uniform, random=true,
        dependency_fun="clamp.(0.1 .+ 0.15 .* gender .+ 0.04 .* log.(parental), 0.1, 0.35)"),
    
    r = dist(min=0.12, max=0.12, distribution=Uniform, random=true),
    K = dist(min=1.2, max=1.2, distribution=Uniform, random=true),

    w̃ = dist(dependent=(:price, :time, :efficiency, :aio),
        dependency_fun="(price .* time .* efficiency .* (1 .- aio)) ./ (1 .+ price .* time .* efficiency .* (1 .- aio))"),
    ū = dist(dependent=(:efficiency),
        dependency_fun="clamp.(efficiency ./ (1 .+ efficiency), 0.02, 1.2)")
)
sample!(PHILIPPINES)
