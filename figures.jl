function phaseplot(S;vector_field=false, show_realized=false)
    f=Figure()
    a=Axis(f[1,1])
    hidespines!(a)
    phaseplot!(a,S,show_trajectory=true;vector_field,show_realized)
    f
end

function incomes(S)
    f=Figure()
    a=Axis(f[1,1])
    hidespines!(a)
    incomes!(a,S)
    f
end

function SEDplot(S,vx,vy; show_density=false, sort=true, markersize=5, labels=true, icons=false, icon_size=30, color=nothing)

    f=Figure()
    a=Axis(f[1,1])
    hidespines!(a)
    SEDplot!(a,S,vx,vy; show_density, sort, markersize, labels, icons, icon_size, color)
    f
end

include("system_dynamics_figure.jl")

function martyPlot(S)
    f=Figure(size=(1000,800))
    w_q_plot=Axis(f[1,1])
    w̃_ū_plot=Axis(f[1,2])
    w̃_vs_ū_plot=Axis(f[1,3])
    xlims!(w̃_vs_ū_plot,0.1,1.0)
    ylims!(w̃_vs_ū_plot,0.0,0.2)
    phaseplane=Axis(f[2:3,1:2])
    incomes_nd=Axis(f[2,3])
    SEDplot!(w_q_plot,S,:id,:w, color=colorant"crimson")
    SEDplot!(w_q_plot,S,:id,:q, color=colorant"steelblue")
    SEDplot!(w̃_ū_plot,S,:id,:w̃, color=colorant"crimson")
    SEDplot!(w̃_ū_plot,S,:id,:ū, color=colorant"steelblue")
    SEDplot!(w̃_vs_ū_plot,S,:w̃,:ū, color=colorant"gray")
    phaseplot!(phaseplane,S, show_trajectory=true)
    incomes!(incomes_nd,S, fix_xlim=false)
    f
end


function figureInstitutions(;show_realized=false,N=20,size=(1200,900),p=1)
    f=Figure(;size)

        PermitLow=Axis(f[1,1], aspect=1, title="Permits low w")
        hidespines!(PermitLow)
        #hidedecorations!(PermitLow)

        PermitHigh=Axis(f[1,2], aspect=1, title="Permits high w")
        hidespines!(PermitHigh)
        #hidedecorations!(PermitHigh)

        ECeffort=Axis(f[2,1], aspect=1, title="Shared Effort")
        hidespines!(ECeffort)
        #hidedecorations!(ECeffort)

        ECyield=Axis(f[2,2], aspect=1, title="Shared Yield")
        hidespines!(ECyield)
        #hidedecorations!(ECyield)

        TQeffort=Axis(f[3,1], aspect=1, title="Tradable Effort")
        hidespines!(TQeffort)
        #hidedecorations!(TQeffort)

        TQyield=Axis(f[3,2], aspect=1, title="Tradable Yield")
        hidespines!(TQyield)
        #hidedecorations!(TQyield)

        protectedArea=Axis(f[1:2,3:4], aspect=1, title="Protected Area")
        hidespines!(protectedArea)
        #hidedecorations!(protectedArea)

        price=Axis(f[3,3], aspect=1, title="Price tax/sub")
        hidespines!(price)
        #hidedecorations!(price)

        effort=Axis(f[3,4], aspect=1, title="Effort tax/sub")
        hidespines!(effort)
        #hidedecorations!(effort)

        numactors1=Axis(f[4,1], aspect=1, title="Single actor")
        hidespines!(numactors1)
        #hidedecorations!(numactors1)
        numactors2=Axis(f[4,2], aspect=1, title="10 actors")
        hidespines!(numactors2)
        #hidedecorations!(numactors2)
        numactors3=Axis(f[4,3], aspect=1, title="100 actors")
        hidespines!(numactors3)
        #hidedecorations!(numactors3)

        test=Axis(f[1:3,1:4])
        hidespines!(test)
        hidedecorations!(test)
        high=:crimson
        medium=:gray
        low=:steelblue
        phaseplot!(PermitLow,scenario(institution="PLL",target="effort",value=0.1, color=:black;N,p);show_realized)
        phaseplot!(PermitLow,scenario(institution="PLL",target="effort",value=0.1,color=low;N,p);show_realized, show_potential=false, show_required=false)
        phaseplot!(PermitLow,scenario(institution="PLL",target="effort",value=0.25,color=medium;N,p);show_realized, show_potential=false, show_required=false)
        phaseplot!(PermitLow,scenario(institution="PLL",target="effort",value=0.4,color=high;N,p);show_realized, show_potential=false, show_required=false)
       
        phaseplot!(PermitHigh,scenario(institution="PHL",target="effort",value=0.1,color=:black;N,p);show_realized)
        phaseplot!(PermitHigh,scenario(institution="PHL",target="effort",value=0.1,color=low;N,p);show_realized, show_potential=false, show_required=false)
        phaseplot!(PermitHigh,scenario(institution="PHL",target="effort",value=0.25,color=medium;N,p);show_realized, show_potential=false, show_required=false)
        phaseplot!(PermitHigh,scenario(institution="PHL",target="effort",value=0.4,color=high;N,p);show_realized, show_potential=false, show_required=false)
        I="EC"
        phaseplot!(ECeffort,scenario(institution=I,target="effort",value=0.1,color=:black;N,p);show_realized)
        phaseplot!(ECeffort,scenario(institution=I,target="effort",value=0.1,color=low;N,p);show_realized, show_potential=false, show_required=false)
        phaseplot!(ECeffort,scenario(institution=I,target="effort",value=0.25,color=medium;N,p);show_realized, show_potential=false, show_required=false)
        phaseplot!(ECeffort,scenario(institution=I,target="effort",value=0.4,color=high;N,p);show_realized, show_potential=false, show_required=false)

        phaseplot!(ECyield,scenario(institution=I,target="yield",value=0.1,color=:black;N,p);show_realized)
        phaseplot!(ECyield,scenario(institution=I,target="yield",value=0.1,color=low;N,p);show_realized, show_potential=false, show_required=false)
        phaseplot!(ECyield,scenario(institution=I,target="yield",value=0.2,color=medium;N,p);show_realized, show_potential=false, show_required=false)
        phaseplot!(ECyield,scenario(institution=I,target="yield",value=0.3,color=high;N,p);show_realized, show_potential=false, show_required=false)

        I="TQ"
        phaseplot!(TQeffort,scenario(institution=I,target="effort",value=0.1,color=:black;N,p);show_realized)
        phaseplot!(TQeffort,scenario(institution=I,target="effort",value=0.1,color=low;N,p);show_realized, show_potential=false, show_required=false)
        phaseplot!(TQeffort,scenario(institution=I,target="effort",value=0.25,color=medium;N,p);show_realized, show_potential=false, show_required=false)
        phaseplot!(TQeffort,scenario(institution=I,target="effort",value=0.4,color=high;N,p);show_realized, show_potential=false, show_required=false)

        phaseplot!(TQyield,scenario(institution=I,target="yield",value=0.1,color=:black;N,p);show_realized)
        phaseplot!(TQyield,scenario(institution=I,target="yield",value=0.1,color=low;N,p);show_realized, show_potential=false, show_required=false)
        phaseplot!(TQyield,scenario(institution=I,target="yield",value=0.2,color=medium;N,p);show_realized, show_potential=false, show_required=false)
        phaseplot!(TQyield,scenario(institution=I,target="yield",value=0.3,color=high;N,p);show_realized, show_potential=false, show_required=false)

        attractor_size=10
        magma=ColorSchemes.viridis
        me=2.0
        y=[sim(scenario(ē=SED(mean=me,sigma=0.0),institution="PA",target="yield",value=v)).y for v in range(0.0,stop=1.0,length=100)]
        U=[sim(scenario(ē=SED(mean=me,sigma=0.0),institution="PA",target="yield",value=v)).U for v in range(0.0,stop=1.0,length=100)]
        lines!(protectedArea,y,U,color=:black)
        phaseplot!(protectedArea,scenario(ē=SED(mean=me,sigma=0.0),institution="PA",target="yield",value=0.1,color=get(magma, 0.1)), show_target=false;attractor_size)
        phaseplot!(protectedArea,scenario(ē=SED(mean=me,sigma=0.0),institution="PA",target="yield",value=0.2,color=get(magma, 0.2)), show_target=false;attractor_size)
        phaseplot!(protectedArea,scenario(ē=SED(mean=me,sigma=0.0),institution="PA",target="yield",value=0.3,color=get(magma, 0.3)), show_target=false;attractor_size)
        phaseplot!(protectedArea,scenario(ē=SED(mean=me,sigma=0.0),institution="PA",target="yield",value=0.4,color=get(magma, 0.4)), show_target=false;attractor_size)
        phaseplot!(protectedArea,scenario(ē=SED(mean=me,sigma=0.0),institution="PA",target="yield",value=0.5,color=get(magma, 0.5)), show_target=false;attractor_size)
        phaseplot!(protectedArea,scenario(ē=SED(mean=me,sigma=0.0),institution="PA",target="yield",value=0.6,color=get(magma, 0.6)), show_target=false;attractor_size)
        phaseplot!(protectedArea,scenario(ē=SED(mean=me,sigma=0.0),institution="PA",target="yield",value=0.7,color=get(magma, 0.7)), show_target=false;attractor_size)
        phaseplot!(protectedArea,scenario(ē=SED(mean=me,sigma=0.0),institution="PA",target="yield",value=0.8,color=get(magma, 0.8)), show_target=false;attractor_size)
        phaseplot!(protectedArea,scenario(ē=SED(mean=me,sigma=0.0),institution="PA",target="yield",value=0.9,color=get(magma, 0.9)), show_target=false;attractor_size)

        
        phaseplot!(price,scenario(p=0.5/p, color=:black;N);show_realized)
        phaseplot!(price,scenario(p=0.5/p,color=low;N);show_realized, show_potential=true, show_required=false)
        phaseplot!(price,scenario(p=1.0/p,color=medium;N);show_realized, show_potential=true, show_required=false)
        phaseplot!(price,scenario(p=2.0/p,color=high;N);show_realized, show_potential=true, show_required=false)

        #phaseplot!(effort,scenario(q=SED(mean=0.5,sigma=0.0,normalize=true), color=:black);show_realized)
        phaseplot!(effort,scenario(q=SED(mean=0.5,sigma=0.0,normalize=true),color=low;N,p);show_realized)
        phaseplot!(effort,scenario(q=SED(mean=1.0,sigma=0.0,normalize=true),color=medium;N,p);show_realized)
        phaseplot!(effort,scenario(q=SED(mean=2.0,sigma=0.0,normalize=true),color=high;N,p);show_realized)
        
#        phaseplot!(numactors1,scenario(color=:gray,N=1;p))
#        phaseplot!(numactors2,scenario(color=:gray,N=10;p))
#        phaseplot!(numactors3,scenario(color=:gray,N=100;p))
#        phaseplot!(numactors1,scenario(color=:steelblue,N=1;p);show_realized, show_potential=false, show_required=false)
#        phaseplot!(numactors2,scenario(color=:steelblue,N=10;p);show_realized, show_potential=false, show_required=false)
#        phaseplot!(numactors3,scenario(color=:steelblue,N=100;p);show_realized, show_potential=false, show_required=false)
        
        save("graphics/institutions.png",f)
        #lines!(test,[0,200],[0,200],color=:gray)
        Label(f[0,1:2], "Actor restrictions",fontsize=26,color=:black)
        Label(f[0,3:4], "Changing Incentives",fontsize=26,color=:black)
        text!(test,0.1,0.9,text="Test label inside",space = :relative)
        f
    end

function figure6(s::Scenario;M=100,size=750,institutions=[("Open","access"),("Protected","area"),("Permits","for low w̃"),("Permits","for high w̃"),("Shared","effort"),("Shared","yield"),("Tradable","effort"),("Tradable","yield")], saveas="",colorscheme=ColorSchemes.tab10)
    ms=3
    f=Figure(size=(size,size*4/3))
    imageplot=Axis(f[0,1])
    corrplot=f[2,1]=GridLayout()
    phaseplot=Axis(f[3,1], backgroundcolor=:lightgray )
    insttotal=Axis(f[1,2])
    instresource=Axis(f[2,2])
    instgini=Axis(f[3,2])
    open=Axis(f[0,3])
    total=Axis(f[1,3])
    resource=Axis(f[2,3])
    gini=Axis(f[3,3])
    LS=[]

    img = load("graphics/"*s.image)
    hidespines!(imageplot)

    for plot in [imageplot,phaseplot,insttotal,insttotal,instresource,instgini,open,total,resource,gini]
        hidedecorations!(plot)
    end
    
    image!(imageplot, rotr90(img))

    V=Dict()
    V[1,1]=(:id,:p)
    V[2,1]=(:id,:ē)
    V[3,1]=(:id,:a)
    V[1,2]=(:id,:w)
    V[2,2]=(:id,:q)
    V[3,2]=(:w̃,cumsum)
    V[1,3]=(:id,:w̃)
    V[2,3]=(:id,:ū)
    V[3,3]=(:w̃,:ū)

    function setBG(v)
        if v[1]==:ū || v[1]==:w̃ || v[2]==:ū || v[2]==:w̃
            return :lightgray
        else
            return :white
        end
        
    end

    A=Dict()
    [A[i]=Axis(corrplot[i...], backgroundcolor=setBG(V[i])) for i in keys(V)]

 

    [SEDplot!(A[i], s, V[i][1], V[i][2],markersize=ms) for i in keys(V)]
    [V[i][2]!=cumsum ? text!(A[i],0.05,0.75,text=string(V[i][2]),space=:relative, color=:black) : nothing for i in keys(V)]
    [V[i][1]!=:id ? text!(A[i],0.75,0.01,text=string(V[i][1]),space=:relative, color=:black) : nothing for i in keys(V)]

    
    [hidespines!(A[i,j]) for i in 1:3, j in 1:3]
    [hidedecorations!(A[i,j]) for i in 1:3, j in 1:3]
    rowgap!(corrplot, 1)
    colgap!(corrplot, 1)

    phaseplot!(phaseplot,s,show_trajectory=true)


    de=0
    d=0
    T=0
    TI=()
    R=0
    RI=()
    G=100000000
    GI=()
    LS=[]
    
    for (j,inst) in enumerate(institutions)
        
        s.institution=inst[1]
        s.target=inst[2]
        de=get_best_target(s;M)
        l=lines!(insttotal,de.target,de.total,  color=colorscheme[j])
        lines!(instresource,de.target,de.resource,  color=colorscheme[j])
        lines!(instgini,de.target,de.gini,  color=colorscheme[j])
        push!(LS,PolyElement(color = colorscheme[j], strokecolor = :transparent))

        if maximum(de.total)>T
            T=maximum(de.total)
            TI=(inst[1],inst[2],de.target[argmax(de.total)],j)
        end


        if maximum(de.resource)>R 
            R=maximum(de.resource)
            RI=(inst[1],inst[2],de.target[argmax(de.resource)],j)
        end

        if minimum(de.gini)<G
            G=minimum(de.gini)
            GI=(inst[1],inst[2],de.target[argmin(de.gini)],j)
        end

    end
    scatter!(insttotal,[TI[3]],[T],  color=colorscheme[TI[4]],markersize=15)
    scatter!(instresource,[RI[3]],[R],  color=colorscheme[RI[4]],markersize=15)
    scatter!(instgini,[GI[3]],[G],  color=colorscheme[GI[4]],markersize=15)
    scatter!(insttotal,[1],[de.total[end]],  color=colorscheme[1],markersize=15)
    scatter!(instresource,[1],[de.resource[end]],  color=colorscheme[1],markersize=15)
    scatter!(instgini,[1],[de.gini[end]],  color=colorscheme[1],markersize=15)
    
    
    s.institution="Open"
    s.target="access"
    s.color=convert(HSL,colorscheme[1])
    sim(s)
    incomes!(open,s,anntext="Open Access",annotation_size=10)

    s.institution=TI[1]
    s.target=TI[2]
    s.value=TI[3]
    s.color=convert(HSL,colorscheme[TI[4]])
    sim(s)
    incomes!(total,s,anntext=TI[1]*" "*TI[2]*" @ "*string(round(TI[3],digits=2)),annotation_size=10)


    s.institution=RI[1]
    s.target=RI[2]
    s.value=RI[3]
    s.color=convert(HSL,colorscheme[RI[4]])
    sim(s)
    incomes!(resource,s,anntext=RI[1]*" "*RI[2]*" @ "*string(round(RI[3],digits=2)),annotation_size=10)


    s.institution=GI[1]
    s.target=GI[2]
    s.value=GI[3]
    s.color=convert(HSL,colorscheme[GI[4]])
    sim(s)
    incomes!(gini,s,anntext=GI[1]*" "*GI[2]*" @ "*string(round(GI[3],digits=2)),annotation_size=10)
    linkaxes!([total,resource,gini]...) 

    LI=[inst[1]*" "*inst[2] for inst in institutions][:]
    Legend(f[0,2],LS,LI,nbanks=1,orientation=:vertical,title="Institutions",framevisible = false,backgroundcolor=:lightgray, tellwidth=false)
     
     saveas=="" ? nothing : save("graphics/"*saveas,f)
    f
end


function figure6(S::Array{Scenario};size=120,institutions=[("Open","access"),("Protected","area"),("Permits","for low w̃"),("Permits","for high w̃"),("Shared","effort"),("Shared","yield"),("Tradable","effort"),("Tradable","yield")],M=100,saveas="Figure6.png", icons=true,showimages=true,resource_revenues=true,covariations=true, ms=2)
    
    width=length(S)*size+50
    caseheight=size+ (showimages ? size : 0) + (covariations ? size : 0)
    institutionsheight=240*0.75+(resource_revenues ? size*0.75 : 0)
    outcomesheight=3*size*0.75+(resource_revenues ? size*0.75 : 0)
    legendheight=size*0.5
    height=caseheight+institutionsheight+outcomesheight+legendheight
    icon_size=30
    f=Figure(;size=(width,height*1.3))
    cases=f[1,1]=GridLayout(height=caseheight)
    institutions_plots=f[2,1]=GridLayout(height=institutionsheight )
    outcomes=f[4,1]=GridLayout(height=outcomesheight )
    total=[]
    resource=[]
    gini=[]
    LS=[]
    #Label(cases[1,0], "Covariances",fontsize=16,rotation=pi/2)
    for (i,s) in enumerate(S)
        
        if showimages
            img = load("graphics/"*s.image)
            s.color=convert(HSL,ColorSchemes.tab10[1])
            imageplot=Axis(cases[1, i], title=s.caption, ylabel="Scenarios")
            hidespines!(imageplot)
            hidexdecorations!(imageplot)
            hideydecorations!(imageplot, label = i==1 ? false : true)
            s.image!="" ? image!(imageplot, rotr90(img)) : nothing
        end

        

        
        if covariations
            tempA=Axis(cases[1+(showimages ? 1 : 0),i])
            i==1 ? tempA.ylabel="Covariation imprint" : nothing
            hidespines!(tempA)
            hideydecorations!(tempA,label=false)
            hidexdecorations!(tempA)
            corrplot=cases[1+(showimages ? 1 : 0),i]=GridLayout()#Axis(cases[1,i])
            colgap!(corrplot, 1)
            rowgap!(corrplot, 1)
            cp=Axis(corrplot[1,1])
            cē=Axis(corrplot[2,1])
            cq=Axis(corrplot[1,2])
            cw=Axis(corrplot[2,2])
            cū=Axis(corrplot[1,3], backgroundcolor=:lightgray)
            cw̃=Axis(corrplot[2,3], backgroundcolor=:lightgray)
            
            # Hide spines and decorations
            for ax in [cp, cē, cq, cw, cū, cw̃]
                hidespines!(ax)
                hidedecorations!(ax)
            end

            # Adjust gaps after all axes are in place
            colgap!(corrplot, 1)
            rowgap!(corrplot, 1)



            scatter!(cp,s.p,markersize=ms)
            scatter!(cē,s.ē,markersize=ms)
            scatter!(cq,s.q,markersize=ms)
            scatter!(cw,s.w,markersize=ms)
            scatter!(cū,s.ū,markersize=ms)
            scatter!(cw̃,s.w̃,markersize=ms)
            
            if icons
                y_icon = load("graphics/p.png")
                scatter!(cp, 0.2, 0.85, marker=y_icon, markersize=icon_size, space=:relative)
                y_icon = load("graphics/ē.png")
                scatter!(cē, 0.2, 0.85, marker=y_icon, markersize=icon_size, space=:relative)
                y_icon = load("graphics/q.png")
                scatter!(cq, 0.2, 0.85, marker=y_icon, markersize=icon_size, space=:relative)
                y_icon = load("graphics/w.png")
                scatter!(cw, 0.2, 0.85, marker=y_icon, markersize=icon_size, space=:relative)  
                y_icon = load("graphics/ū.png")
                scatter!(cū, 0.2, 0.85, marker=y_icon, markersize=icon_size, space=:relative)
                y_icon = load("graphics/w̃.png")
                scatter!(cw̃, 0.2, 0.85, marker=y_icon, markersize=icon_size, space=:relative)
            end
            
            if icons==false
                text!(cp,0.1,0.7,text="p",space=:relative, color=:black)
                text!(cē,0.1,0.7,text="ē",space=:relative, color=:black)
                text!(cq,0.1,0.7,text="q",space=:relative, color=:black)
                text!(cw,0.1,0.7,text="w",space=:relative, color=:black)
                text!(cū,0.1,0.7,text="ū",space=:relative, color=:black)
                text!(cw̃,0.1,0.7,text="w̃",space=:relative, color=:black)
            end
        end
        phase=Axis(cases[1+(showimages ? 1 : 0) + (covariations ? 1 : 0),i], backgroundcolor=:lightgray, ylabel="System dynamics")     
        hidespines!(phase)     
        hidexdecorations!(phase)
        hideydecorations!(phase, label = i==1 ? false : true)
        phaseplot!(phase,S[i],show_trajectory=true)

        
        push!(total,Axis(institutions_plots[1,i],ylabel="Total",yautolimitmargin=(0.1f0, 0.1f0)))
        hidespines!(total[i])
        hidexdecorations!(total[i],label=false)
        hideydecorations!(total[i],label= i==1 ? false : true)

        
        if resource_revenues
            push!(resource,Axis(institutions_plots[2,i],ylabel="Resource",yautolimitmargin=(0.1f0, 0.1f0)))
            hidespines!(resource[i])
            hidexdecorations!(resource[i],label=false)
            hideydecorations!(resource[i],label=i==1 ? false : true)
        end
        
        push!(gini,Axis(institutions_plots[1+ (resource_revenues ? 2 : 1),i],ylabel="Gini",xlabel="Restriction",xticks = (0:1, ["1", "0"]),yautolimitmargin=(0.1f0, 0.1f0)))
        hidespines!(gini[i])      
        hidexdecorations!(gini[i],label=false,ticks=false,ticklabels=false, grid=true)
        hideydecorations!(gini[i],label=i==1 ? false : true)

        de=0
        d=0
        T=0
        TI=()
        R=0
        RI=()
        G=100000000
        GI=()
        LS=[]
        
        for (j,inst) in enumerate(institutions)
            
            s.institution=inst[1]
            s.target=inst[2]
            de=get_best_target(s;M)
            l=lines!(total[i],de.target,de.total,  color=ColorSchemes.tab10[j])
            resource_revenues ? lines!(resource[i],de.target,de.resource,  color=ColorSchemes.tab10[j]) : nothing
            lines!(gini[i],de.target,de.gini,  color=ColorSchemes.tab10[j])
            push!(LS,PolyElement(color = ColorSchemes.tab10[j], strokecolor = :transparent))

            if maximum(de.total)>T
                T=maximum(de.total)
                TI=(inst[1],inst[2],de.target[argmax(de.total)],j)
            end


            if maximum(de.resource)>R && resource_revenues
                R=maximum(de.resource)
                RI=(inst[1],inst[2],de.target[argmax(de.resource)],j)
            end

            if minimum(de.gini)<G
                G=minimum(de.gini)
                GI=(inst[1],inst[2],de.target[argmin(de.gini)],j)
            end

        end
        scatter!(total[i],[TI[3]],[T],  color=ColorSchemes.tab10[TI[4]],markersize=15)
        resource_revenues ? scatter!(resource[i],[RI[3]],[R],  color=ColorSchemes.tab10[RI[4]],markersize=15) : nothing
        scatter!(gini[i],[GI[3]],[G],  color=ColorSchemes.tab10[GI[4]],markersize=15)
        
        
        Iopen=Axis(outcomes[ 1,i],ylabel="Access")#, ylabelsize=12)#, title="Open Access")
        
        Itotal=Axis(outcomes[ 2,i],ylabel="Total")#, ylabelsize=12)#, title=TI[1]*" "*TI[2]*" "*string(round(TI[3],digits=2)))
        if resource_revenues 
            Iresource=Axis(outcomes[3,i], ylabel="Resource") 
            
        end
        Igini=Axis(outcomes[2 + (resource_revenues ? 2 : 1),i],ylabel="Gini")#, ylabelsize=12)#, title=GI[1]*" "*GI[2]*" "*string(round(GI[3],digits=2)))
        #ylims!(Iopen,0.0,0.015)
        #ylims!(Itotal,0.0,0.015)
        #ylims!(Iresource,0.0,0.015)
        #ylims!(Igini,0.0,0.015)

        hidespines!(Iopen)
        hidespines!(Itotal)
        hidespines!(Igini)

        hidexdecorations!(Iopen)
        hidexdecorations!(Itotal)
        hidexdecorations!(Igini)

        hideydecorations!(Iopen,label=i==1 ? false : true)
        hideydecorations!(Itotal,label=i==1 ? false : true)
        hideydecorations!(Igini,label=i==1 ? false : true)

        if resource_revenues
            hidespines!(Iresource)
            hidexdecorations!(Iresource)
            hideydecorations!(Iresource,label=i==1 ? false : true)
        end

        s.institution="Open"
        s.target="access"
        s.color=convert(HSL,ColorSchemes.tab10[1])
        sim(s)
        incomes!(Iopen,s,anntext="Open Access",annotation_size=10)

        s.institution=TI[1]
        s.target=TI[2]
        s.value=TI[3]
        s.color=convert(HSL,ColorSchemes.tab10[TI[4]])
        sim(s)
        incomes!(Itotal,s,anntext=TI[1]*" "*TI[2]*" @ "*string(round(TI[3],digits=2)),annotation_size=10)

        if resource_revenues
            s.institution=RI[1]
            s.target=RI[2]
            s.value=RI[3]
            s.color=convert(HSL,ColorSchemes.tab10[RI[4]])
            sim(s)
            incomes!(Iresource,s,anntext=RI[1]*" "*RI[2]*" @ "*string(round(RI[3],digits=2)),annotation_size=10)
        end
        s.institution=GI[1]
        s.target=GI[2]
        s.value=GI[3]
        s.color=convert(HSL,ColorSchemes.tab10[GI[4]])
        sim(s)
        incomes!(Igini,s,anntext=GI[1]*" "*GI[2]*" @ "*string(round(GI[3],digits=2)),annotation_size=10)
        resource_revenues ? linkaxes!([Iopen,Itotal,Iresource,Igini]...) : linkaxes!([Iopen,Itotal,Igini]...)
    end
    #b=cases[0:2,0]=GridLayout(f[1, 1], tellwidth = false, tellheight = false, halign = :right, valign = :bottom)
    #Box(b, color = "#eeeeee", strokecolor = :transparent)
    Label(cases[1:(1+(showimages ? 1 : 0) + (covariations ? 1 : 0)),0], "Scenarios",fontsize=20,color=:gray, rotation=pi/2)
    #Box(institutions_plots[1:3,0], color = "#eeeeee", strokecolor = :transparent)
    Label(institutions_plots[1:(resource_revenues ? 3 : 2),0], "Institutional effects ⇦",fontsize=20,color=:gray, rotation=pi/2)
    #Box(outcomes[1:4,0], color = "#eeeeee", strokecolor = :transparent)
    Label(outcomes[1:(resource_revenues ? 4 : 3),0], "Best Outcomes ⇦",fontsize=20,color=:gray, rotation=pi/2)
    LI=[inst[1]*" "*inst[2] for inst in institutions][:]
   # LS=[LS[1:5],LS[6:8]]
   # LI=[LI[1:5],LI[6:8]]
    Legend(f[3,1],LS,LI,nbanks=2,orientation=:horizontal, height=legendheight,title="Institutions",framevisible = false,backgroundcolor=:lightgray)
    saveas=="" ? nothing : save("graphics/"*saveas,f)
    f
end


function getBestInst(s,institutions;M=100)
    T=0
    TI=[]
    R=0
    RI=[]
    G=100000000
    GI=[]
    AT=[]
    AR=[]
    AG=[]
    YT=[]
    YR=[]
    YG=[]
    for (j,inst) in enumerate(institutions)
        
        s.institution=inst[1]
        s.target=inst[2]
        de=get_best_target(s;M)
        push!(AT,de.total)
        push!(AR,de.resource)
        push!(AG,de.gini)
            T=round(maximum(de.total),digits=4)
            push!(TI,(inst[1],inst[2],de.target[argmax(de.total)],j,T))
            YT=de.y[argmax(de.total)]

            R=round(maximum(de.resource),digits=4)
            push!(RI,(inst[1],inst[2],de.target[argmax(de.resource)],j,R))
            YR=de.y[argmax(de.resource)]

            G=round(minimum(de.gini),digits=4)
            push!(GI,(inst[1],inst[2],de.target[argmin(de.gini)],j,G))
            YG=de.y[argmin(de.gini)]
    end

    return (;TI,RI,GI,T,R,G,AT,AR,AG,institutions,YT,YR,YG)
end



##### We could save the rank of each institution at each position
# and then we can extract all first ranks (and best target) for full figure
function institutionalExploration(;show_fig=true,cov=0,M=5,Q=100, institutions=[("OA","effort"),("PLL","effort"),("PHL","effort"),("EC","effort"),("EC","yield"),("TQ","effort"),("TQ","yield")])
    

    OAT=zeros(M,M)
    OAR=zeros(M,M)
    OAG=zeros(M,M)
    IT=zeros(M,M)
    IR=zeros(M,M)
    IG=zeros(M,M)
    BT=zeros(M,M)
    BR=zeros(M,M)
    BG=zeros(M,M)
    Tv=zeros(M,M)
    Rv=zeros(M,M)
    Gv=zeros(M,M)
    YT=zeros(M,M)
    YR=zeros(M,M)
    YG=zeros(M,M)
    W=zeros(M,M)
    U=zeros(M,M)
    for (i,w̃) in enumerate(range(0.0+0.5/M,stop=1.5-0.5/M,length=M))
        for (j,ū) in enumerate(range(0.0+0.5/M,stop=2.0-0.5/M,length=M))
            L=[]
            s=scenario(;w̃=SED(min=0.0,max=w̃),ū=SED(mean=ū,sigma=ū.*0.99*cov, normalize=true))
            OAT[i,j]=sum(sim(s).total_revenue)
            OAR[i,j]=sum(sim(s).resource_revenue)
            OAG[i,j]=sim(s).gini
            b=getBestInst(s,institutions,M=Q)
            TI=selectBestInst(b.TI,max=true)
            RI=selectBestInst(b.RI,max=true)
            GI=selectBestInst(b.GI,max=false)
            IT[i,j]=TI[1]
            IR[i,j]=RI[1]
            IG[i,j]=GI[1]
            BT[i,j]=b.T
            BR[i,j]=b.R
            BG[i,j]=b.G
            Tv[i,j]=b.TI[TI[1]][3]
            Rv[i,j]=b.RI[RI[1]][3]
            Gv[i,j]=b.GI[GI[1]][3]
            YT[i,j]=b.YT
            YR[i,j]=b.YR
            YG[i,j]=b.YG
            W[i,j]=w̃
            U[i,j]=ū
            if show_fig 
                f=Figure() 
                a=Axis(f[1,1])
                bb=Axis(f[1,2],title="total")
                c=Axis(f[2,1],title="resource")
                d=Axis(f[2,2],title="gini")
                phaseplot!(a,s)
                for (i,t) in enumerate(b.AG)
                    l=lines!(bb,b.AT[i])
                    lines!(c,b.AR[i])
                    lines!(d,b.AG[i])
                    push!(L,l)
                end
                Legend(f[1:2,3],L,[n[1]*" "*n[2] for n in institutions])
                display(f)
            end

            println(i,j)
        end
    end
    w̃=range(0.0+1/M,stop=1.0-1/M,length=M)
    ū=range(0.0+1/M,stop=1.0-1/M,length=M)
    return (;OAT,OAR,OAG,IT,IR,IG,BT,BR,BG,Tv,Rv,Gv,w̃,ū,YT,YR,YG,institutions,W,U)
end

function selectBestInst(x;max=true)
    m=max ? maximum([y[5] for y in x]) : minimum([y[5] for y in x])
    f=findall([y[5] for y in x].==m)
    if 1 in f  # BUT if OA is not at index 1!!!!!
         return 1
    else
       if length(f)>1
            return f
        else
            return f[1]
        end
    end
end

function figureHeatplots(b)
    institutions=[("OA","effort"),("PLL","effort"),("PHL","effort"),("EC","effort"),("EC","yield"),("TQ","effort"),("TQ","yield")]
    f=Figure(size=(900,1200))
    OAT,OAR,OAG,IT,IR,IG,BT,BR,BG,Tv,Rv,Gv=b
    w̃=range(0.0+1/size(OAT,1),stop=1.0-1/size(OAT,1),length=size(OAT,1))
    ū=range(0.0+1/size(OAT,2),stop=1.0-1/size(OAT,2),length=size(OAT,2))
    cmap=Symbol("Set1_"*string(length(institutions)))
   # (OAT,OAR,OAG,IT,IR,IG,BT,BR,BG,Tv,Rv,Gv,w̃,ū)=b
    aOAT=Axis(f[1,1],aspect=1, title="OAT")
    aOAR=Axis(f[1,2],aspect=1,title="OAR")
    aOAG=Axis(f[1,3],aspect=1,title="OAG")
    aIT=Axis(f[2,1],aspect=1,title="IT")
    aIR=Axis(f[2,2],aspect=1,title="IR")
    aIG=Axis(f[2,3],aspect=1,title="IG")
    aBT=Axis(f[3,1],aspect=1,title="BT")
    aBR=Axis(f[3,2],aspect=1,title="BR")
    aBG=Axis(f[3,3],aspect=1,title="BG")
    aTv=Axis(f[4,1],aspect=1,title="Tv")
    aRv=Axis(f[4,2],aspect=1,title="Rv")
    aGv=Axis(f[4,3],aspect=1,title="Gv")
    #=hidespines!(aOAT)
    hidespines!(aOAR)
    hidespines!(aOAG)
    hidespines!(aIT)
    hidespines!(aIR)
    hidespines!(aIG)
    hidespines!(aBT)
    hidespines!(aBR)
    hidespines!(aBG)
    hidespines!(aTv)
    hidespines!(aRv)
    hidespines!(aGv)
    hidedecorations!(aOAT,grid=false)
    hidedecorations!(aOAR,grid=false)
    hidedecorations!(aOAG,grid=false)
    hidedecorations!(aIT,grid=false)
    hidedecorations!(aIR,grid=false)
    hidedecorations!(aIG,grid=false)
    hidedecorations!(aBT,grid=false)
    hidedecorations!(aBR,grid=false)
    hidedecorations!(aBG,grid=false)
    hidedecorations!(aTv,grid=false)
    hidedecorations!(aRv,grid=false)
    hidedecorations!(aGv,grid=false)=#
    heatmap!(aOAT,w̃,ū,OAT',show_axis=false)
    heatmap!(aOAR,w̃,ū,OAR',show_axis=false)
    heatmap!(aOAG,w̃,ū,OAG',show_axis=false)
    heatmap!(aIT,w̃,ū,IT',show_axis=false,colormap=cmap,colorrange=(0,7))
    heatmap!(aIR,w̃,ū,IR',show_axis=false,colormap=cmap,colorrange=(0,7))
    heatmap!(aIG,w̃,ū,IG',show_axis=false,colormap=cmap,colorrange=(0,7))
    heatmap!(aBT,w̃,ū,BT'.-OAT',show_axis=false)
    heatmap!(aBR,w̃,ū,BR'.-OAR',show_axis=false)
    heatmap!(aBG,w̃,ū,OAG'.-BG',show_axis=false)
    heatmap!(aTv,w̃,ū,Tv',show_axis=false)
    heatmap!(aRv,w̃,ū,Rv',show_axis=false)
    heatmap!(aGv,w̃,ū,Gv',show_axis=false)
f
end


SA()=[scenario(q=SED(mean=2.0,sigma=1.9,normalize=true),image="case1.png",label="High effort \n low opportunities",color=convert(HSL,ColorSchemes.tab10[1])),
#scenario(q=SED(mean=2.0,sigma=0.0,normalize=true)),
scenario(q=SED(mean=2.0,sigma=-1.9,normalize=true),image="case2.png",label="High effort \n low opportunities",color=convert(HSL,ColorSchemes.tab10[1])),
scenario(q=SED(mean=0.8,sigma=0.79,normalize=true),w=SED(mean=0.09,sigma=0.089,normalize=true),image="case3.png",label="High effort \n low opportunities",color=convert(HSL,ColorSchemes.tab10[1])),
#scenario(q=SED(mean=0.8,sigma=0.0,normalize=true),w=SED(mean=0.09,sigma=0.089,normalize=true)),
scenario(q=SED(mean=0.8,sigma=-0.79,normalize=true),w=SED(mean=0.09,sigma=0.089,normalize=true),image="case4.png",label="High effort \n low opportunities",color=convert(HSL,ColorSchemes.tab10[1]))
]

SB()=[scenario(q=SED(mean=2.0,sigma=1.9,normalize=true,rand=true),image="case1.png",caption="Mediterranean\n coastal town",color=convert(HSL,ColorSchemes.tab10[1])),
#scenario(q=SED(mean=2.0,sigma=0.0,normalize=true)),
scenario(q=SED(mean=2.0,sigma=-1.9,normalize=true),image="case2.png",caption="High latitude \n western town",color=convert(HSL,ColorSchemes.tab10[1])),
scenario(q=SED(mean=0.8,sigma=0.0,normalize=true),w=SED(mean=0.09,sigma=0.089,normalize=true, rand=true, distribution=LogNormal),image="case3.png",caption="Latin american \n coastal town",color=convert(HSL,ColorSchemes.tab10[1])),
#scenario(q=SED(mean=0.8,sigma=0.0,normalize=true),w=SED(mean=0.09,sigma=0.089,normalize=true)),
scenario(q=SED(mean=0.8,sigma=-0.79,normalize=true),w=SED(mean=0.09,sigma=0.089,normalize=true),image="case4.png",caption="East european \n village",color=convert(HSL,ColorSchemes.tab10[1])),
scenario(q=SED(mean=0.8,sigma=-0.4,normalize=true),w=SED(mean=0.09,sigma=0.089,normalize=true, distribution=LogNormal),image="case5.png",caption="Southeast asian \n fishing community",color=convert(HSL,ColorSchemes.tab10[1]))
]

SC()=[scenario(q=SED(mean=2.0,sigma=1.9,normalize=true,rand=true),image="case1.png",caption="Mediterranean\n coastal town",color=convert(HSL,ColorSchemes.tab10[1])),
#scenario(q=SED(mean=2.0,sigma=0.0,normalize=true)),
scenario(q=SED(mean=2.0,sigma=-1.9,normalize=true),image="case2.png",caption="High latitude \n western town",color=convert(HSL,ColorSchemes.tab10[1]))]

function test(b)
    f=Figure(size=(800,900))
    (OAT,OAR,OAG,IT,IR,IG,BT,BR,BG,Tv,Rv,Gv,w̃,ū)=b
    aOAT=Axis(f[1,1],aspect=1)
    aIT=Axis(f[2,1],aspect=1)
    aBT=Axis(f[3,1],aspect=1)
    aTv=Axis(f[4,1],aspect=1)
    aGv=Axis(f[5,1],aspect=1)
    heatmap!(aOAT,w̃,ū,OAT,show_axis=false)
    heatmap!(aIT,w̃,ū,IT,show_axis=false)
    heatmap!(aBT,w̃,ũ,BT,show_axis=false)
    heatmap!(aTv,w̃,ũ,Tv,show_axis=false)
    heatmap!(aGv,w̃,ũ,Gv,show_axis=false)
end

#=
h5open(homedir()*"/Documents/heatmaps.h5", "w") do file
    # Save each field of the named tuple separately
    for name in keys(test)
        println(name)
        if test[name] isa AbstractRange
            file[String(name)] = collect(test[name]) # Convert range to array before saving
        else 
        file[String(name)] = test[name]
        end
    end
end


w̃=0.2
ū=0.8
W=range(0.0+1/M,stop=1.0-1/M,length=M)
U=range(0.0+1/M,stop=1.0-1/M,length=M)
i=1
j=1
s=scenario(;w̃=SED(mean=W[i],sigma=W[i]*0.99),ū=SED(mean=U[j],sigma=0.0, normalize=true))
i=getBestInst(s,institutions,M=100)
f=Figure()
a=Axis(f[1,1])
#ylims!(a,(0.2359,0.241))
L=[]
for t in i.AG
    l=lines!(a,t)
    push!(L,l)
    println(minimum(t))
end
Legend(f[1,2],L,[n[1]*" "*n[2] for n in institutions])
f
=#




function sed(;N1=20,N2=200,w_dist=LogNormal,ms=1)
    f=Figure()
    low_N_distributions=f[1,1]=GridLayout()
    high_N_distributions=f[2,1]=GridLayout()
    low_N_phaseplot=Axis(f[1,2])
    high_N_phaseplot=Axis(f[2,2])

    s1=scenario(w̃=SED(min=0.1,max=0.6,distribution=w_dist, rand=true),ū=SED(mean=0.8,sigma=0.0,normalize=true,rand=true),N=N1,color=:black)
    s2=scenario(w̃=SED(min=0.1,max=0.6,distribution=w_dist),ū=SED(mean=0.8,sigma=0.0,normalize=true),N=N1)
    s3=scenario(w̃=SED(min=0.1,max=0.6,distribution=w_dist, rand=true),ū=SED(mean=0.8,sigma=0.0,normalize=true,rand=true),N=N2,color=:black)
    s4=scenario(w̃=SED(min=0.1,max=0.6,distribution=w_dist),ū=SED(mean=0.8,sigma=0.0,normalize=true),N=N2)


    V=Dict()
    V[1,1]=(:id,:p)
    V[2,1]=(:id,:ē)
    V[3,1]=(:id,:a)
    V[1,2]=(:id,:w)
    V[2,2]=(:id,:q)
    V[3,2]=(:w̃,cumsum)
    V[1,3]=(:id,:w̃)
    V[2,3]=(:id,:ū)
    V[3,3]=(:w̃,:ū)

    function setBG(v)
        if v[1]==:ū || v[1]==:w̃ || v[2]==:ū || v[2]==:w̃
            return :lightgray
        else
            return :white
        end
        
    end

    A=Dict()
    [A[i]=Axis(low_N_distributions[i...], backgroundcolor=setBG(V[i])) for i in keys(V)]
    B=Dict()
    [B[i]=Axis(high_N_distributions[i...], backgroundcolor=setBG(V[i])) for i in keys(V)]

 

    [SEDplot!(A[i], s1, V[i][1], V[i][2],markersize=ms) for i in keys(V)]
    [SEDplot!(A[i], s2, V[i][1], V[i][2],markersize=ms) for i in keys(V)]
    [SEDplot!(B[i], s3, V[i][1], V[i][2],markersize=ms) for i in keys(V)]
    [SEDplot!(B[i], s4, V[i][1], V[i][2],markersize=ms) for i in keys(V)]
    [V[i][2]!=cumsum ? text!(A[i],0.05,0.75,text=string(V[i][2]),space=:relative, color=:black) : text!(A[i],0.05,0.75,text="cdf",space=:relative, color=:black) for i in keys(V)]
    [V[i][1]!=:id ? text!(A[i],0.75,0.01,text=string(V[i][1]),space=:relative, color=:black) : nothing for i in keys(V)]
    [V[i][2]!=cumsum ? text!(B[i],0.05,0.75,text=string(V[i][2]),space=:relative, color=:black) : text!(B[i],0.05,0.75,text="cdf",space=:relative, color=:black) for i in keys(V)]
    [V[i][1]!=:id ? text!(B[i],0.75,0.01,text=string(V[i][1]),space=:relative, color=:black) : nothing for i in keys(V)]

    
    [hidespines!(A[i,j]) for i in 1:3, j in 1:3]
    [hidedecorations!(A[i,j]) for i in 1:3, j in 1:3]
    rowgap!(low_N_distributions, 1)
    colgap!(low_N_distributions, 1)    
    [hidespines!(B[i,j]) for i in 1:3, j in 1:3]
    [hidedecorations!(B[i,j]) for i in 1:3, j in 1:3]
    rowgap!(high_N_distributions, 1)
    colgap!(high_N_distributions, 1)




    phaseplot!(low_N_phaseplot,s1,show_realized=false, show_attractor=false)
    phaseplot!(low_N_phaseplot,s2,show_realized=false, show_attractor=false,show_vertical_potential=true)
    phaseplot!(high_N_phaseplot,s3,show_realized=false, show_attractor=false)
    phaseplot!(high_N_phaseplot,s4,show_realized=false, show_attractor=false,show_vertical_potential=true)

    display(f)
end

function arrow_arc!(ax, origin, radius, start_angle, stop_angle; linewidth=1, color=:black)
    # Draw the arc
    arc!(ax, origin, radius, start_angle, stop_angle, linewidth=linewidth, color=color)

    # Function to calculate a point on the circle
    point_on_circle(θ) = origin .+ radius * Point2f(cos(θ), sin(θ))

    # Calculate the direction of the arrow at the start and end of the arc
    start_dir = Point2f(cos(start_angle + π/2), sin(start_angle + π/2))
    end_dir = Point2f(cos(stop_angle - π/2), sin(stop_angle - π/2))
    dx=0.000000001
    # Add arrow at the start and end of the arc
    # Adjust the multiplier for start_dir and end_dir to control the arrow orientation
    arrows!(ax, [point_on_circle(start_angle)[1]],[point_on_circle(start_angle)[2]], [start_dir[1]]*dx,[start_dir[2]]*dx, color=color, linewidth=linewidth)
    arrows!(ax, [point_on_circle(stop_angle)[1]],[point_on_circle(stop_angle)[2]], [end_dir[1]]*dx,[end_dir[2]]*dx, color=color, linewidth=linewidth)
end

function region_of_control(;N=1000, distribution=LogNormal)
    dc=1.1
    f=Figure(size=(1000,1000))
    ax1=Axis(f[1,1])
    ax2=Axis(f[1,2])
    ax3=Axis(f[2,1])
    ax4=Axis(f[2,2])
    myscheme = ColorScheme([colorant"forestgreen",colorant"darkorange", colorant"steelblue"],
    "custom", "twotone, red and green")
    for u in [0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.92,1.07,1.26,1.5,1.87,2.5,3.75,8.0]
        s=scenario(w̃=SED(mean=0.3,sigma=0.0),    ū=SED(mean=u,sigma=0.0, normalize=true), color=u<0.8 ? :forestgreen : :steelblue;N)
        du=scenario(w̃=SED(mean=0.3,sigma=0.0),    ū=SED(mean=u*dc,sigma=0.0, normalize=true), color=u<0.8 ? :forestgreen : :steelblue;N)
        dw=scenario(w̃=SED(mean=0.3*dc,sigma=0.0),    ū=SED(mean=u,sigma=0.0, normalize=true), color=u<0.8 ? :forestgreen : :steelblue;N)
        dwV=(sum(dw.resource_revenue)-sum(s.resource_revenue))/(1-dc)
        duV=(sum(du.resource_revenue)-sum(s.resource_revenue))/(1-dc)
        s.color=convert(HSL,get(myscheme,abs(dwV)/(abs(dwV)+abs(duV))))
        phaseplot!(ax1,s,show_realized=false, show_attractor=true,show_vertical_potential=true)
        dwV=(sum(dw.total_revenue)-sum(s.total_revenue))/dc
        duV=(sum(du.total_revenue)-sum(s.total_revenue))/dc
        s.color=convert(HSL,get(myscheme,abs(dwV)/(abs(dwV)+abs(duV))))
        phaseplot!(ax3,s,show_realized=false, show_attractor=true,show_vertical_potential=true)

        sLN=scenario(w̃=SED(mean=0.3,sigma=0.4,distribution=distribution),    ū=SED(mean=u,sigma=0.0, normalize=true);N)
        du=scenario(w̃=SED(mean=0.3,sigma=0.4,distribution=distribution),    ū=SED(mean=u*dc,sigma=0.0, normalize=true);N)
        dw=scenario(w̃=SED(mean=0.3*dc,sigma=0.4,distribution=distribution),    ū=SED(mean=u,sigma=0.0, normalize=true);N)
        dwV=(sum(dw.resource_revenue)-sum(sLN.resource_revenue))/(1-dc)
        duV=(sum(du.resource_revenue)-sum(sLN.resource_revenue))/(1-dc) 
        println(abs(dwV)/(abs(dwV)+abs(duV)))
        sLN.color=convert(HSL,get(myscheme,abs(dwV)/(abs(dwV)+abs(duV))))
        phaseplot!(ax2,sLN,show_realized=false, show_attractor=true,show_vertical_potential=true)
        dwV=(sum(dw.total_revenue)-sum(sLN.total_revenue))/(1-dc)
        duV=(sum(du.total_revenue)-sum(sLN.total_revenue))/(1-dc)
        println(abs(dwV)/(abs(dwV)+abs(duV)))
        sLN.color=convert(HSL,get(myscheme,abs(dwV)/(abs(dwV)+abs(duV))))
        phaseplot!(ax4,sLN,show_realized=false, show_attractor=true,show_vertical_potential=true)
    end
    arrows!(ax1,[0.3],[0.5],[0.14],[0.0],linewidth=2.0,color=:steelblue)
    arrows!(ax1,[0.3],[0.5],[-0.14],[0.0],linewidth=2.0,color=:steelblue)
    #arrows!(ax1,[0.65],[0.95],[0.34],[0.0],linewidth=2.0,color=:forestgreen)
    #arrows!(ax1,[0.65],[0.95],[-0.34],[0.0],linewidth=2.0,color=:forestgreen)
    arrow_arc!(ax1,Point2f(1, 0),0.9,pi-0.96-0.01,pi/2+0.01,linewidth=2.0,color=:forestgreen)
    text!(ax1,0.47,0.45,text="mean incentive\ncontrols resource", color=:steelblue,fontsize=20)
    text!(ax1,0.60,0.65,text="mean impact\ncontrols resource", color=:forestgreen,fontsize=20,rotation=0.32)
    text!(ax2,0.37,0.45,text="Mixed control of\nmean incentive and impact", color=:black,fontsize=20)
   
    #text!(ax2,0.37,0.25,text="when does individual u affect \n total revenues?", color=:black,fontsize=20)
    Colorbar(f[1:2, 3],limits = (0, 1), colormap = myscheme,flipaxis = false,ticks=([0,1],["impact","incentive"]))
    Label(f[1,0],text="Resource revenue",rotation=pi/2,fontsize=20, tellheight=false)
    Label(f[2,0],text="Total revenue",rotation=pi/2,fontsize=20,tellheight=false)
    Label(f[0,1],text="No diversity",fontsize=20,tellwidth=false)
    Label(f[0,2],text="Realistic distribution",fontsize=20,tellwidth=false)
    Label(f[0,3],text="Control",fontsize=20,tellwidth=false,halign=:right)
    Label(f[3,1:2],text="Resource level",fontsize=20,tellwidth=false)
    save("graphics/region_of_control.png",f)
    f
end