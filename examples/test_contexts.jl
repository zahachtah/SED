w = (
        N = 100,
        health = sed(min=0.0001, max=1.0, distribution=LogNormal),
        gender = sed(mean=0.5,  distribution=Bernoulli),
        parental = sed(min=0.1, max=1.0, distribution=LogNormal),
        time=sed(dependency_fun="health*(1-gender*sed)", min=0, max=1),
        efficiency = sed(min=0.1, max=0.9,  dependency_fun="parental*(1-gender*0.5)"),
        alternatives = sed(min=0.001, max=0.6, distribution=LogNormal, dependency_fun="(1-gender*0.3)*sed"),
        K = 2.0,
        IMPACT = sed(min=-0.1,max=0.1,dependency_fun="time*efficiency"),
        INCENTIVE = sed(min=-0.1, max=0.1, dependency_fun="(alternatives ./ efficiency) .+ sed"),
    )

W = (
        N = 100,
        health = sed(min=0.0001, max=1.0, distribution=LogNormal),
        gender = sed(mean=0.5,  distribution=Bernoulli),
        parental = sed(min=0.1, max=1.0, distribution=LogNormal),
        time=sed(dependency_fun="health*(1-gender*sed)", min=0, max=1),
        efficiency = sed(min=0.1, max=0.9,  dependency_fun="parental*(1-gender*0.5)"),
        alternatives = sed(min=0.001, max=0.6, distribution=LogNormal, dependency_fun="(1-gender*0.3)*sed"),
        K = 2.0,
        ū = sed(min=-0.1,max=0.1,dependency_fun="time*efficiency"),
        w̃ = sed(min=-0.1, max=0.1, dependency_fun="(alternatives ./ efficiency) .+ sed"),
        α = sed(min=0.1, max=0.1,distribution=Uniform) #fill(0.1,100)#
    )
