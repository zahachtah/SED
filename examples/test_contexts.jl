w = (
    N=100,
    health=dist(min=0.0001, max=1.0, distribution=LogNormal),
    gender=dist(mean=0.5, distribution=Bernoulli),
    parental=dist(min=0.1, max=1.0, distribution=LogNormal),
    time=dist(dependency_fun="health*(1-gender*dist)", min=0, max=1),
    efficiency=dist(min=0.1, max=0.9, dependency_fun="parental*(1-gender*0.5)"),
    alternatives=dist(min=0.001, max=0.6, distribution=LogNormal, dependency_fun="(1-gender*0.3)*dist"),
    K=2.0,
    IMPACT=dist(min=-0.1, max=0.1, dependency_fun="time*efficiency"),
    INCENTIVE=dist(min=-0.1, max=0.1, dependency_fun="(alternatives ./ efficiency) .+ dist"),
)

W = (
    N=100,
    health=dist(min=0.0001, max=1.0, distribution=LogNormal, dependency_fun="1-independent"),
    gender=dist(mean=0.5, distribution=Bernoulli),
    parental=dist(min=0.1, max=1.0, distribution=LogNormal),
    time=dist(dependency_fun="(1-health)*(1-gender*independent)", min=0, max=1),
    efficiency=dist(min=0.1, max=0.9, dependency_fun="parental*(1-gender*0.5)"),
    alternatives=dist(min=0.001, max=0.6, distribution=LogNormal, dependency_fun="parental*(1-gender*0.3)*independent"),
    K=2.0,
    ū=dist(min=-0.1, max=0.1, dependency_fun="time*efficiency"),
    w̃=dist(min=-0.1, max=0.1, dependency_fun="(alternatives ./ efficiency) .+ independent"),
    α=dist(min=0.1, max=0.1, distribution=Uniform) #fill(0.1,100)#
)

T = (
    N=100,
    test=dist(min=0.0001, max=1.0, distribution=LogNormal),
    health=dist(min=0.0001, max=1.0, distribution=LogNormal, dependency_fun="1-max(0.0,independent)"),
    gender=dist(mean=0.5, distribution=Bernoulli),
    time=dist(dependency_fun="health*(1-gender*0.5)*independent", min=0, max=1),
)
