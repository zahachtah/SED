function phaseplot(S;vector_field=false)
    f=Figure()
    a=Axis(f[1,1])
    hidespines!(a)
    phaseplot!(a,S,show_trajectory=true;vector_field)
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

function martyPlot(S)
    f=Figure(resolution=(1000,800))
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
        y=[sim(scenario(ē=SED(mean=me,spread=0.0),institution="PA",target="yield",value=v)).y for v in range(0.0,stop=1.0,length=100)]
        U=[sim(scenario(ē=SED(mean=me,spread=0.0),institution="PA",target="yield",value=v)).U for v in range(0.0,stop=1.0,length=100)]
        lines!(protectedArea,y,U,color=:black)
        phaseplot!(protectedArea,scenario(ē=SED(mean=me,spread=0.0),institution="PA",target="yield",value=0.1,color=get(magma, 0.1)), show_target=false;attractor_size)
        phaseplot!(protectedArea,scenario(ē=SED(mean=me,spread=0.0),institution="PA",target="yield",value=0.2,color=get(magma, 0.2)), show_target=false;attractor_size)
        phaseplot!(protectedArea,scenario(ē=SED(mean=me,spread=0.0),institution="PA",target="yield",value=0.3,color=get(magma, 0.3)), show_target=false;attractor_size)
        phaseplot!(protectedArea,scenario(ē=SED(mean=me,spread=0.0),institution="PA",target="yield",value=0.4,color=get(magma, 0.4)), show_target=false;attractor_size)
        phaseplot!(protectedArea,scenario(ē=SED(mean=me,spread=0.0),institution="PA",target="yield",value=0.5,color=get(magma, 0.5)), show_target=false;attractor_size)
        phaseplot!(protectedArea,scenario(ē=SED(mean=me,spread=0.0),institution="PA",target="yield",value=0.6,color=get(magma, 0.6)), show_target=false;attractor_size)
        phaseplot!(protectedArea,scenario(ē=SED(mean=me,spread=0.0),institution="PA",target="yield",value=0.7,color=get(magma, 0.7)), show_target=false;attractor_size)
        phaseplot!(protectedArea,scenario(ē=SED(mean=me,spread=0.0),institution="PA",target="yield",value=0.8,color=get(magma, 0.8)), show_target=false;attractor_size)
        phaseplot!(protectedArea,scenario(ē=SED(mean=me,spread=0.0),institution="PA",target="yield",value=0.9,color=get(magma, 0.9)), show_target=false;attractor_size)

        
        phaseplot!(price,scenario(p=0.5/p, color=:black;N);show_realized)
        phaseplot!(price,scenario(p=0.5/p,color=low;N);show_realized, show_potential=true, show_required=false)
        phaseplot!(price,scenario(p=1.0/p,color=medium;N);show_realized, show_potential=true, show_required=false)
        phaseplot!(price,scenario(p=2.0/p,color=high;N);show_realized, show_potential=true, show_required=false)

        #phaseplot!(effort,scenario(q=SED(mean=0.5,spread=0.0,normalize=true), color=:black);show_realized)
        phaseplot!(effort,scenario(q=SED(mean=0.5,spread=0.0,normalize=true),color=low;N,p);show_realized)
        phaseplot!(effort,scenario(q=SED(mean=1.0,spread=0.0,normalize=true),color=medium;N,p);show_realized)
        phaseplot!(effort,scenario(q=SED(mean=2.0,spread=0.0,normalize=true),color=high;N,p);show_realized)
        
        phaseplot!(numactors1,scenario(color=:gray,N=1;p))
        phaseplot!(numactors2,scenario(color=:gray,N=10;p))
        phaseplot!(numactors3,scenario(color=:gray,N=100;p))
        phaseplot!(numactors1,scenario(color=:steelblue,N=1;p);show_realized, show_potential=false, show_required=false)
        phaseplot!(numactors2,scenario(color=:steelblue,N=10;p);show_realized, show_potential=false, show_required=false)
        phaseplot!(numactors3,scenario(color=:steelblue,N=100;p);show_realized, show_potential=false, show_required=false)
        
        save("graphics/institutions.png",f)
        #lines!(test,[0,200],[0,200],color=:gray)
        Label(f[0,1:2], "Actor restrictions",fontsize=26,color=:black)
        Label(f[0,3:4], "Changing Incentives",fontsize=26,color=:black)
        text!(test,0.1,0.9,text="Test label inside",space = :relative)
        f
    end


function figure6(S::Array{Scenario};size=(700,1200),institutions=[("Open","access"),("Protected","area"),("Permits","for low w̃"),("Permits","for high w̃"),("Shared","effort"),("Shared","yield"),("Tradable","effort"),("Tradable","yield")],M=100,saveas="Figure6.png", icons=true)
    icon_size=30
    f=Figure(;size)
    cases=f[1,1]=GridLayout(height=400,backgroundcolor=:lightgray)
    institutions_plots=f[2,1]=GridLayout(height=250,rowgap=1)
    outcomes=f[4,1]=GridLayout(rowgap=1)
    total=[]
    resource=[]
    gini=[]
    LS=[]
    #Label(cases[1,0], "Covariances",fontsize=16,rotation=pi/2)
    for (i,s) in enumerate(S)

        img = load("graphics/"*s.image)
        s.color=convert(HSL,ColorSchemes.tab10[1])#HSL(0.0,0.0,0.2)
        

        
        phase=Axis(cases[2,i], backgroundcolor=:lightgray, ylabel="System dynamics ⇦")
        imageplot=Axis(cases[0, i], title=s.caption, ylabel="Scenarios")

        s.image!="" ? image!(imageplot, rotr90(img)) : nothing
        hidespines!(phase)
        #hidespines!(corrplot)
        hidespines!(imageplot)
        
        hidexdecorations!(phase)
        hideydecorations!(phase, label = i==1 ? false : true)
        #hidedecorations!(corrplot)
        hidexdecorations!(imageplot)
        hideydecorations!(imageplot, label = i==1 ? false : true)

        tempA=Axis(cases[1,i],ylabel="Covariation imprint")
        hidespines!(tempA)
        hideydecorations!(tempA,label=false)
        hidexdecorations!(tempA)
        corrplot=cases[1,i]=GridLayout()#Axis(cases[1,i])
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



        scatter!(cp,s.p,markersize=5)
        scatter!(cē,s.ē,markersize=5)
        scatter!(cq,s.q,markersize=5)
        scatter!(cw,s.w,markersize=5)
        scatter!(cū,s.ū,markersize=5)
        scatter!(cw̃,s.w̃,markersize=5)

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

       # scatter!(corrplot,s.w,s.q,markersize=5)

        phaseplot!(phase,S[i])


        push!(total,Axis(institutions_plots[1,i],ylabel="Total",yautolimitmargin=(0.1f0, 0.1f0)))
        push!(resource,Axis(institutions_plots[2,i],ylabel="Resource",yautolimitmargin=(0.1f0, 0.1f0)))
        push!(gini,Axis(institutions_plots[3,i],ylabel="Gini",xlabel="Restriction",xticks = (0:1, ["max", "no"]),yautolimitmargin=(0.1f0, 0.1f0)))
        hidespines!(total[i])
        hidespines!(resource[i])
        hidespines!(gini[i])      
        hidexdecorations!(total[i],label=false)
        hidexdecorations!(resource[i],label=false)
        hidexdecorations!(gini[i],label=false,ticks=false,ticklabels=false, grid=true)
        hideydecorations!(total[i],label= i==1 ? false : true)
        hideydecorations!(resource[i],label=i==1 ? false : true)
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
            lines!(resource[i],de.target,de.resource,  color=ColorSchemes.tab10[j])
            lines!(gini[i],de.target,de.gini,  color=ColorSchemes.tab10[j])
            push!(LS,PolyElement(color = ColorSchemes.tab10[j], strokecolor = :transparent))

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
        scatter!(total[i],[TI[3]],[T],  color=ColorSchemes.tab10[TI[4]],markersize=15)
        scatter!(resource[i],[RI[3]],[R],  color=ColorSchemes.tab10[RI[4]],markersize=15)
        scatter!(gini[i],[GI[3]],[G],  color=ColorSchemes.tab10[GI[4]],markersize=15)
        Iopen=Axis(outcomes[1,i],ylabel="Access")#, ylabelsize=12)#, title="Open Access")
        Itotal=Axis(outcomes[2,i],ylabel="Total")#, ylabelsize=12)#, title=TI[1]*" "*TI[2]*" "*string(round(TI[3],digits=2)))
        Iresource=Axis(outcomes[3,i], ylabel="Resource")#, ylabelsize=12)#, title=RI[1]*" "*RI[2]*" "*string(round(RI[3],digits=2)))
        Igini=Axis(outcomes[4,i],ylabel="Gini")#, ylabelsize=12)#, title=GI[1]*" "*GI[2]*" "*string(round(GI[3],digits=2)))
        #ylims!(Iopen,0.0,0.015)
        #ylims!(Itotal,0.0,0.015)
        #ylims!(Iresource,0.0,0.015)
        #ylims!(Igini,0.0,0.015)

        hidespines!(Iopen)
        hidespines!(Itotal)
        hidespines!(Iresource)
        hidespines!(Igini)

        hidexdecorations!(Iopen)
        hidexdecorations!(Itotal)
        hidexdecorations!(Iresource)
        hidexdecorations!(Igini)

        hideydecorations!(Iopen,label=i==1 ? false : true)
        hideydecorations!(Itotal,label=i==1 ? false : true)
        hideydecorations!(Iresource,label=i==1 ? false : true)
        hideydecorations!(Igini,label=i==1 ? false : true)

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

        s.institution=RI[1]
        s.target=RI[2]
        s.value=RI[3]
        s.color=convert(HSL,ColorSchemes.tab10[RI[4]])
        sim(s)
        incomes!(Iresource,s,anntext=RI[1]*" "*RI[2]*" @ "*string(round(RI[3],digits=2)),annotation_size=10)

        s.institution=GI[1]
        s.target=GI[2]
        s.value=GI[3]
        s.color=convert(HSL,ColorSchemes.tab10[GI[4]])
        sim(s)
        incomes!(Igini,s,anntext=GI[1]*" "*GI[2]*" @ "*string(round(GI[3],digits=2)),annotation_size=10)
        linkaxes!([Iopen,Itotal,Iresource,Igini]...)
    end
    #b=cases[0:2,0]=GridLayout(f[1, 1], tellwidth = false, tellheight = false, halign = :right, valign = :bottom)
    #Box(b, color = "#eeeeee", strokecolor = :transparent)
    Label(cases[0:2,0], "Characterizing Scenarios",fontsize=20,color=:gray, rotation=pi/2)
    #Box(institutions_plots[1:3,0], color = "#eeeeee", strokecolor = :transparent)
    Label(institutions_plots[1:3,0], "Institutional effects ⇦",fontsize=20,color=:gray, rotation=pi/2)
    #Box(outcomes[1:4,0], color = "#eeeeee", strokecolor = :transparent)
    Label(outcomes[1:4,0], "Best Income/Inequality Outcome ⇦",fontsize=20,color=:gray, rotation=pi/2)
    LI=[inst[1]*" "*inst[2] for inst in institutions][:]
   # LS=[LS[1:5],LS[6:8]]
   # LI=[LI[1:5],LI[6:8]]
    Legend(f[3,1],LS,LI,nbanks=2,orientation=:horizontal, title="Institutions",framevisible = false,backgroundcolor=:lightgray)
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
            s=scenario(;w̃=SED(min=0.0,max=w̃),ū=SED(mean=ū,spread=ū.*0.99*cov, normalize=true))
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


SA()=[scenario(q=SED(mean=2.0,spread=1.9,normalize=true),image="case1.png",label="High effort \n low opportunities",color=convert(HSL,ColorSchemes.tab10[1])),
#scenario(q=SED(mean=2.0,spread=0.0,normalize=true)),
scenario(q=SED(mean=2.0,spread=-1.9,normalize=true),image="case2.png",label="High effort \n low opportunities",color=convert(HSL,ColorSchemes.tab10[1])),
scenario(q=SED(mean=0.8,spread=0.79,normalize=true),w=SED(mean=0.09,spread=0.089,normalize=true),image="case3.png",label="High effort \n low opportunities",color=convert(HSL,ColorSchemes.tab10[1])),
#scenario(q=SED(mean=0.8,spread=0.0,normalize=true),w=SED(mean=0.09,spread=0.089,normalize=true)),
scenario(q=SED(mean=0.8,spread=-0.79,normalize=true),w=SED(mean=0.09,spread=0.089,normalize=true),image="case4.png",label="High effort \n low opportunities",color=convert(HSL,ColorSchemes.tab10[1]))
]

SB()=[scenario(q=SED(mean=2.0,spread=1.9,normalize=true,rand=true),image="case1.png",caption="Mediterranean\n coastal town",color=convert(HSL,ColorSchemes.tab10[1])),
#scenario(q=SED(mean=2.0,spread=0.0,normalize=true)),
scenario(q=SED(mean=2.0,spread=-1.9,normalize=true),image="case2.png",caption="High latitude \n western town",color=convert(HSL,ColorSchemes.tab10[1])),
scenario(q=SED(mean=0.8,spread=0.79,normalize=true),w=SED(mean=0.09,spread=0.089,normalize=true, rand=true),image="case3.png",caption="Latin american \n coastal town",color=convert(HSL,ColorSchemes.tab10[1])),
#scenario(q=SED(mean=0.8,spread=0.0,normalize=true),w=SED(mean=0.09,spread=0.089,normalize=true)),
scenario(q=SED(mean=0.8,spread=-0.79,normalize=true),w=SED(mean=0.09,spread=0.089,normalize=true),image="case4.png",caption="East european \n village",color=convert(HSL,ColorSchemes.tab10[1])),
scenario(q=SED(mean=0.8,spread=-0.4,normalize=true),w=SED(mean=0.09,spread=-0.089,normalize=true),image="case5.png",caption="Southeast asian \n fishing community",color=convert(HSL,ColorSchemes.tab10[1]))
]

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
s=scenario(;w̃=SED(mean=W[i],spread=W[i]*0.99),ū=SED(mean=U[j],spread=0.0, normalize=true))
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