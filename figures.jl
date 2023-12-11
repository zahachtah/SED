function phaseplot(S;vector_field=false)
    f=Figure()
    a=Axis(f[1,1])
    hidespines!(a)
    phaseplot!(a,S,show_trajectory=true;vector_field)
    f
end

function incomes(S;vector_field=false)
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