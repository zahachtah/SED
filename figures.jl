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


function figureInstitutions(;show_realized=false)
    f=Figure(resolution=(1200,900))

        PermitLow=Axis(f[1,1], aspect=1, title="Permits low w")
        hidespines!(PermitLow)

        PermitHigh=Axis(f[1,2], aspect=1, title="Permits high w")
        hidespines!(PermitHigh)

        ECeffort=Axis(f[2,1], aspect=1, title="Shared Effort")
        hidespines!(ECeffort)

        ECyield=Axis(f[2,2], aspect=1, title="Shared Yield")
        hidespines!(ECyield)

        TQeffort=Axis(f[3,1], aspect=1, title="Tradable Effort")
        hidespines!(TQeffort)

        TQyield=Axis(f[3,2], aspect=1, title="Tradable Yield")
        hidespines!(TQyield)

        protectedArea=Axis(f[1:2,3:4], aspect=1, title="Protected Area")
        hidespines!(protectedArea)

        price=Axis(f[3,3], aspect=1, title="Price tax/sub")
        hidespines!(price)

        effort=Axis(f[3,4], aspect=1, title="Effort tax/sub")
        hidespines!(effort)

        test=Axis(f[1:3,1:4])
        hidespines!(test)
        hidedecorations!(test)

        phaseplot!(PermitLow,scenario(institution="PLL",target="effort",value=0.1);show_realized)
        phaseplot!(PermitLow,scenario(institution="PLL",target="effort",value=0.25);show_realized)
        phaseplot!(PermitLow,scenario(institution="PLL",target="effort",value=0.4);show_realized)
       
        phaseplot!(PermitHigh,scenario(institution="PHL",target="effort",value=0.1);show_realized)
        phaseplot!(PermitHigh,scenario(institution="PHL",target="effort",value=0.25);show_realized)
        phaseplot!(PermitHigh,scenario(institution="PHL",target="effort",value=0.4);show_realized)
        I="EC"
        phaseplot!(ECeffort,scenario(institution=I,target="effort",value=0.1);show_realized)
        phaseplot!(ECeffort,scenario(institution=I,target="effort",value=0.25);show_realized)
        phaseplot!(ECeffort,scenario(institution=I,target="effort",value=0.4);show_realized)

        phaseplot!(ECyield,scenario(institution=I,target="yield",value=0.1);show_realized)
        phaseplot!(ECyield,scenario(institution=I,target="yield",value=0.2);show_realized)
        phaseplot!(ECyield,scenario(institution=I,target="yield",value=0.3);show_realized)

        I="TQ"
        phaseplot!(TQeffort,scenario(institution=I,target="effort",value=0.1);show_realized)
        phaseplot!(TQeffort,scenario(institution=I,target="effort",value=0.25);show_realized)
        phaseplot!(TQeffort,scenario(institution=I,target="effort",value=0.4);show_realized)

        phaseplot!(TQyield,scenario(institution=I,target="yield",value=0.1);show_realized)
        phaseplot!(TQyield,scenario(institution=I,target="yield",value=0.2);show_realized)
        phaseplot!(TQyield,scenario(institution=I,target="yield",value=0.3);show_realized)


        phaseplot!(protectedArea,scenario(institution="PA",target="yield",value=0.1), show_target=false)
        phaseplot!(protectedArea,scenario(institution="PA",target="yield",value=0.2), show_target=false)
        phaseplot!(protectedArea,scenario(institution="PA",target="yield",value=0.3), show_target=false)
        phaseplot!(protectedArea,scenario(institution="PA",target="yield",value=0.4), show_target=false)
        phaseplot!(protectedArea,scenario(institution="PA",target="yield",value=0.5), show_target=false)
        phaseplot!(protectedArea,scenario(institution="PA",target="yield",value=0.6), show_target=false)
        phaseplot!(protectedArea,scenario(institution="PA",target="yield",value=0.7), show_target=false)
        phaseplot!(protectedArea,scenario(institution="PA",target="yield",value=0.8), show_target=false)
        phaseplot!(protectedArea,scenario(institution="PA",target="yield",value=0.9), show_target=false)
        
        phaseplot!(price,scenario(p=0.5);show_realized)
        phaseplot!(price,scenario(p=1.0);show_realized)
        phaseplot!(price,scenario(p=2.0);show_realized)

        phaseplot!(effort,scenario(q=SED(mean=0.5,spread=0.0,normalize=true));show_realized)
        phaseplot!(effort,scenario(q=SED(mean=1.0,spread=0.0,normalize=true));show_realized)
        phaseplot!(effort,scenario(q=SED(mean=2.0,spread=0.0,normalize=true));show_realized)
        save("graphics/institutions.png",f)
        #lines!(test,[0,200],[0,200],color=:gray)
        text!(test,0.1,0.9,text="Test label inside",space = :relative)
        f
    end

function cases()
end