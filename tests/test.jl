begin
println("Testing SED")
for n in [1,2,10]
    # n= 1 and 2 does not work yet
    P=[(mean=0.2,sigma=0.2),(median=0.2,sigma=0.2),(mean=0.2,sigma=0.0),(median=0.2,sigma=0.0),(min=0.2,max=0.4),(min=0.2,max=0.2),(min=0.4,max=0.2)]
    for d in [LogNormal,Uniform, Constant]
        println("Distribution: ",d)
        for p in P
            d=dist!(SED(distribution=d;p...),n)
            println("\n", "N: ",n," pars: ",p)
            println(d.data)
        end
        dist!(SED(distribution=d,mean=0.2,sigma=0.2),n)
        dist!(SED(distribution=d,median=0.2,sigma=0.2),n)
        dist!(SED(distribution=d,mean=0.2,sigma=0.0),n)
        dist!(SED(distribution=d,median=0.2,sigma=0.0),n)
        dist!(SED(distribution=d,min=0.2,max=0.4),n)
        dist!(SED(distribution=d,min=0.2,max=0.2),n)
    end
    dist!(SED(distribution=LogNormal,min=0.1,max=0.3),n)
    dist!(SED(distribution=LogNormal,median=0.2,sigma=0.2),n)
    dist!(SED(distribution=Uniform,mean=0.2,sigma=0.2),n)
    dist!(SED(distribution=Uniform,min=0.1,max=0.3),n)
    dist!(SED(distribution=Uniform,median=0.2,sigma=0.2),n)
    s=scenario(N=n,w=SED(mean=0.2,sigma=0.2))
    scenario(s,N=2)
end
end