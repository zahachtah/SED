
mutable struct tradable_use_rights_m <: dynamicInstitution
    criteria::Symbol
    threshold::Float64
    reverse::Bool
    target::Symbol
    value::Float64
    control::Symbol
    fun::Function
end

function trade_use_rights(institution::tradable_use_rights_m,du,u,s,t)
    
    if institution.target==:yield
        supply=max(0.0,institution.value-sum(u)*s.y)
        
    elseif institution.target==:effort
        
        supply=max(0.0,institution.value-sum(u))
    end
    
    
    id = findall((du[1:s.N] .> 0.0) .& ((u[1:s.N] ) .< s.ū)) #+ du[1:s.N]
    demand=sum(du[id]) 
    
    if demand > supply # if demand is greater than supply, buyers have to share supply proportionally to their individual demand or willingness to pay.
        
        #du[id].=supply.*min(du[id],s.ū[id].-u[id])./demand
        
    end  
    du[s.N+3]= institution.threshold*(demand -supply)

end

function figure_institutions(;s=scenario(q=SED(mean=1.5,sigma=0.0,random=false,normalize=true), color=:gray))
    # update!(s)
    # copy(s,(:q,(:mean,0.2)))
    dist!(s)
    sim!(s)
    f=Figure(size=(1200,800))
    permit_low_w=CairoMakie.Axis(f[1,1])
    permit_high_w=CairoMakie.Axis(f[1,2])
    equal_share_effort=CairoMakie.Axis(f[2,1])
    equal_share_yield=CairoMakie.Axis(f[2,2])
    tradable_effort=CairoMakie.Axis(f[3,1])
    tradable_yield=CairoMakie.Axis(f[3,2])
    protected_areas_1=CairoMakie.Axis(f[1,3])
    price_tax_sub_1=CairoMakie.Axis(f[2,3])
    effort_tax_sub_1=CairoMakie.Axis(f[3,3])
    protected_areas_2=CairoMakie.Axis(f[1,4])
    price_tax_sub_2=CairoMakie.Axis(f[2,4])
    effort_tax_sub_2=CairoMakie.Axis(f[3,4])
    #s.q.mean=1.0
    #dist!(s);sim!(s)
    phaseplot!(permit_low_w,s,show_realized=true)
    s1=scenario(q=SED(mean=1.5,sigma=0.0,random=false,normalize=true),institution=[dynamic_permit_allocation(:q,true,:test,0.4,:value,dyn_permits)], color=:orange)
    dist!(s1);sim!(s1)
    phaseplot!(permit_low_w,s1,show_realized=true, show_potential=false)
    phaseplot!(permit_high_w,s,show_realized=true)
    phaseplot!(equal_share_effort,s,show_realized=true)
    phaseplot!(equal_share_yield,s,show_realized=true)
    phaseplot!(tradable_effort,s,show_realized=true)
    phaseplot!(tradable_yield,s,show_realized=true)
    phaseplot!(protected_areas_1,s,show_realized=true)
    phaseplot!(price_tax_sub_1,s,show_realized=true)
    phaseplot!(effort_tax_sub_1,s,show_realized=true)
    phaseplot!(protected_areas_2,s,show_realized=true)
    so=scenario(q=SED(mean=0.5,sigma=0.0,random=false,normalize=true), color=:gray)
    dist!(so)
    sim!(so)
    
    phaseplot!(price_tax_sub_2,so,show_realized=true)
    phaseplot!(effort_tax_sub_2,so,show_realized=true)

    # Explicit show who wins and who looses
    # subsidize q, for all,high or low q
    # subsidize price, for all
    # table is to show which cases
    # heading: initial condition (over/under exploitation), intervention type (tradable, permits, price + effort tax/subsidy, protected area), scenarios (equal, linear, inequal poor), correlation (+/0/-)

    # outcomes revenues of 0) openaccess 1) fishery 2) total (%change) 3) gini (%change) 4) Picketty quartiles!? 5) stock

    # when q and w ar correlated then the following is true: xyz
    f

end

function MS_scenarios()
    N=100
    random=false
    wmin=0.05*10
    wmax=0.10*10
    qmin=0.03*20
    qmax=0.2*20
    distribution=Uniform
    steps=2
    S=[ scenario(w̃=SED(median=0.3,sigma=0.3; random, distribution),ū=SED(median=1.0,sigma=1.0, normalize=true; random)),
        scenario(w̃=SED(median=0.3,sigma=-0.3; random, distribution),ū=SED(median=1.0,sigma=1.0, normalize=true; random)),
        scenario(w̃=SED(median=0.7,sigma=0.3; random, distribution),ū=SED(median=1.0,sigma=1.0, normalize=true; random)),
        scenario(w̃=SED(median=0.7,sigma=-0.3; random, distribution),ū=SED(median=1.0,sigma=1.0, normalize=true; random)),
        scenario(w̃=SED(median=0.3,sigma=0.3; random, distribution),ū=SED(median=1.0,sigma=-1.0, normalize=true; random)),
        scenario(w̃=SED(median=0.3,sigma=-0.3; random, distribution),ū=SED(median=1.0,sigma=-1.0, normalize=true; random)),
        scenario(w̃=SED(median=0.7,sigma=0.3; random, distribution),ū=SED(median=1.0,sigma=-1.0, normalize=true; random)),
        scenario(w̃=SED(median=0.7,sigma=-0.3; random, distribution),ū=SED(median=1.0,sigma=-1.0, normalize=true; random)),
        scenario(w̃=SED(median=0.3,sigma=0.3; random, distribution),ū=SED(median=1.0,sigma=0.0, normalize=true; random)),
        scenario(w̃=SED(median=0.3,sigma=-0.3; random, distribution),ū=SED(median=1.0,sigma=0.0, normalize=true; random)),
        scenario(w̃=SED(median=0.7,sigma=0.3; random, distribution),ū=SED(median=1.0,sigma=0.0, normalize=true; random)),
        scenario(w̃=SED(median=0.7,sigma=-0.3; random, distribution),ū=SED(median=1.0,sigma=0.0, normalize=true; random))]
    #=
    for (i, v) in enumerate(range(qmin, stop=qmax, length=steps))
        push!(S,scenario(;N,w=SED(min=wmin,max=wmax, normalize=true, random=rn, distribution=distribution),q=SED(min=v,max=qmax-v,normalize=true, random=rn,),ē=1.0,r=1.0,K=1.0,p=5.0))
    end
    for (i, v) in enumerate(range(qmin, stop=qmax, length=steps))
        push!(S,scenario(;N,w=SED(min=wmin*6,max=wmax*6, normalize=true, random=rn, distribution=distribution),q=SED(min=v*0.5,max=(qmax-v)*0.5,normalize=true, random=rn,),ē=1.0,r=1.0,K=1.0,p=5.0))
    end
    =#
    return S
end

function tableData(;weight=[0,1,1,0,0],plotit=true)

    df=DataFrame(Exploitation=String[], Shape=String[], Correlation=Float64[],Institution=String[],Revenue=Float64[],Total=Float64[],Gini=Float64[],I=Float64[],Y=Float64[], Restriction=Float64[])

    institutions=Dict(
        "permits for high incentives"=>[dynamic_permit_allocation(:w̃,true,:test,0.4,:value,dyn_permits)],
        "permits for low incentives"=>[dynamic_permit_allocation(:w̃,false,:test,0.4,:value,dyn_permits)],
        "equl yield"=>[equal_share_allocation(:w̃,false,:yield,0.2,:nope,equal_share)],
        "equal_effort"=>[equal_share_allocation(:w̃,false,:effort,0.2,:nope,equal_share)]

    )

    Scenarios=MS_scenarios()

    R=zeros(length(Scenarios),length(institutions))
    T=zeros(length(Scenarios),length(institutions))
    G=zeros(length(Scenarios),length(institutions))
    I=zeros(length(Scenarios),length(institutions))
    Y=zeros(length(Scenarios),length(institutions))


    for (k,s) in enumerate(Scenarios)
        dist!(s)
        for (n,i) in enumerate(keys(institutions))
            s.institution=institutions[i]
           
            sim!(s)
            o=institutional_impact(s)
            w=o.resource.^weight[1].*o.total.^weight[2].*o.gini.^weight[3].*o.I.^weight[4].*o.y.^weight[5]
            opt=argmax(w)
            
            push!(df,(o.y[end]<0.5 ? "over" : "under",string(typeof(s.w̃.distribution))[1:end-9],mean(diff(s.w̃)),i,o.resource[opt]/o.resource[end]*100-100,o.total[opt]/o.total[end]*100-100,-(o.gini[opt]/o.gini[end]*100-100),o.I[opt]*100,0.5-o.y[opt]*100-100,o.target[opt]*100))
            R[k,n]=o.resource[opt]/o.resource[end]*100-100
            T[k,n]=o.total[opt]/o.total[end]*100-100
            G[k,n]=o.gini[opt]/o.gini[end]*100-100
            I[k,n]=o.I[opt]*100
            Y[k,n]=0.5-o.y[opt]*100-100
        end
    end
    if plotit
        f=Figure()
        xticks=(1:length(institutions),[string(i) for i in keys(institutions)])
        resources=CairoMakie.Axis(f[1,1], title="Resource", xticks=xticks, xticklabelrotation=-pi/8)
        total=CairoMakie.Axis(f[1,2],title="Total", xticks=xticks, xticklabelrotation=-pi/8)
        gini=CairoMakie.Axis(f[1,3],title="Gini", xticks=xticks, xticklabelrotation=-pi/8)
        In=CairoMakie.Axis(f[1,4],title="Regulation", xticks=xticks, xticklabelrotation=-pi/8)
        Yn=CairoMakie.Axis(f[1,5],title="Stock", xticks=xticks, xticklabelrotation=-pi/8)
        [hidespines!(a) for a in [resources,total,gini,In,Yn]]
        [hideydecorations!(a) for a in [resources,total,gini,In,Yn]]
        

        heatmap!(resources,R',colormap=:bam, colorrange=(-100,100))
        heatmap!(total,T',colormap=:bam, colorrange=(-100,100))
        heatmap!(gini,G',colormap=:bam, colorrange=(-100,100))
        heatmap!(In,I',colormap=:bam)
        heatmap!(Yn,Y',colormap=:bam)
        
        display(f)
    end
    df
end

function lastFigure(df)
    R=zeros(Int64(nrow(df)/length(institutions)),length(institutions))
    T=zeros(Int64(nrow(df)/length(institutions)),length(institutions))
    G=zeros(Int64(nrow(df)/length(institutions)),length(institutions))
    I=zeros(Int64(nrow(df)/length(institutions)),length(institutions))
    Y=zeros(Int64(nrow(df)/length(institutions)),length(institutions))

    k=1
    for E in unique(df[:,"Exploitation"])
        for S in unique(df[:,"Shape"])
            for C in unique(df[:,"Correlation"])
                for (i,I) in enumerate(unique(df[:,"Institution"]))
                    println(df[(df.Exploitation.==E) .& (df.Shape.==S) .& (df.Correlation.==C) .& (df.Institution.==I),:])
                    R[k,i]=df[(df.Exploitation.==E) .& (df.Shape.==S) .& (df.Correlation.==C) .& (df.Institution.==I),:Revenue]  
                    T[k,i]=df[(df.Exploitation.==E) .& (df.Shape.==S) .& (df.Correlation.==C) .& (df.Institution.==I),:Total]
                    G[k,i]=df[(df.Exploitation.==E) .& (df.Shape.==S) .& (df.Correlation.==C) .& (df.Institution.==I),:Gini]
                    I[k,i]=df[(df.Exploitation.==E) .& (df.Shape.==S) .& (df.Correlation.==C) .& (df.Institution.==I),:I]
                    Y[k,i]=df[(df.Exploitation.==E) .& (df.Shape.==S) .& (df.Correlation.==C) .& (df.Institution.==I),:Restriction]
                    
                end
                k+=1
            end
        end
    end



    f=Figure()
    xticks=(1:length(institutions),[string(i) for i in keys(institutions)])
    resources=CairoMakie.Axis(f[1,1], title="Resource", xticks=xticks, xticklabelrotation=-pi/8)
    total=CairoMakie.Axis(f[1,2],title="Total", xticks=xticks, xticklabelrotation=-pi/8)
    gini=CairoMakie.Axis(f[1,3],title="Gini", xticks=xticks, xticklabelrotation=-pi/8)
    In=CairoMakie.Axis(f[1,4],title="Regulation", xticks=xticks, xticklabelrotation=-pi/8)
    Yn=CairoMakie.Axis(f[1,5],title="Stock", xticks=xticks, xticklabelrotation=-pi/8)
    [hidespines!(a) for a in [resources,total,gini,In,Yn]]
    [hideydecorations!(a) for a in [resources,total,gini,In,Yn]]
    

    heatmap!(resources,R',colormap=:bam, colorrange=(-100,100))
    heatmap!(total,T',colormap=:bam, colorrange=(-100,100))
    heatmap!(gini,G',colormap=:bam, colorrange=(-100,100))
    heatmap!(In,I',colormap=:bam)
    heatmap!(Yn,Y',colormap=:bam)
        
        display(f)
end

function checkScenarios(S;base=300)
    F=Figure(size=(2*base,length(S)*base))
    for i in 1:length(S)
        #a=CairoMakie.Axis(F[i,1])
        dist!(S[i])
        sim!(S[i])
        phaseplot!(CairoMakie.Axis(F[i,1]),S[i])
        incomes!(CairoMakie.Axis(F[i,2]),S[i], indexed=false)
    end
    F
end