

include("SEDist_selfcontained.jl");
using Printf
"""

Runs sim and plots a bunch of stuff.   The parameters are 
the same as in sim with some graphics studd added to set
the bounds on the graphs.

wqymax: max on the w and q graph yaxis.
w̃ūymax: same on the non-dimensional graph
ūvw̃ymax: same on the ū versus w̃ graph

"""

function qwcovar(;N=20,
    r=1,
    K=1,
    p=5,
    ē=1,
    qmin=1/N,
    qmax=1/N,
    wmin=0.05,
    wmax=0.20,
    q=range(qmin,qmax,N),
    c=range(0.00,0.00,N),
    wₒ=range(wmin,wmax,N),
    wqymax=nothing,
    w̃ūymax=nothing,
    ūvw̃ymax=nothing
    )

    w = c .+ wₒ;
    c̃=c./(q.*p.*K);
    w̃ₒ=wₒ./(q.*p.*K);
    w̃=sed(data=c̃ .+ w̃ₒ);
    ū=sed(data=ē.*q./r);


    #plot w, q, w̃, ū, sum ū separately
    f=Figure(backgroundcolor = :grey95, title="blah",resolution = (950, 800))
    a1=Axis(f[1,1];title="w and q",limits=(0,nothing,0,wqymax))
    scatter!(a1,w,label="w")
    scatter!(a1,q,label="q")
    axislegend(a1)

    a2=Axis(f[1,2];title="w̃ and ū",limits=(0,nothing,0,w̃ūymax))
    scatter!(a2,w̃,label="w̃")
    scatter!(a2,ū,label="ū")
    axislegend(a2)

    a3=Axis(f[1,3];title="ū versus w̃",limits=(0,2.0,0,ūvw̃ymax))

    scatter!(a3,w̃,ū)


    a4=Axis(f[1,4];title="sum of ū",aspect=0.8, xticklabelsvisible= false,ytickformat="{:.1f}")
    scatter!(a4,range(sum(ū),sum(ū),N))

    s=sim(scenario(base();N,w̃,ū));

    #non-dimensional revenues
    u=s.u[end][1:N]
    y=s.u[end][end]
    R̃ₒ = (ū .- u) .* w̃ₒ; 
    R̃ₕ = u.*(y .- c̃);
    R̃ₕᵣ= u.*(y .- w̃);
    R̃ = R̃ₒ .+  R̃ₕ;

    #dimensional revenues

    Rₒ = r*p*K*R̃ₒ
    Rₕ = r*p*K*R̃ₕ
    Rₕᵣ = r*p*K*R̃ₕᵣ
    R = r*p*K*R̃


   # fig2=Figure(backgroundcolor = :grey95, resolution = (950, 1000))
    ax1 = Axis(f[3, 1:2], title = "Income distribution in units of p",
               ylabel = "Net Revenue \n (income), p",
               xlabel="opportunity cost")
    ax2 = Axis(f[3, 3:4], title = "non-dimensional Income distrbution",
               ylabel = "Net Revenue \n (income), rpK",
               xlabel = "non-dimensional opportunity cost")
    ax3 = Axis(f[4, 1:2],xlabel="Agent index")
    ax4 = Axis(f[4, 3:4],xlabel = "Agent index")
    barplot!(ax1,w,R,color=:blue)
    barplot!(ax1,w,Rₕ,color=:green)
    barplot!(ax1,w,Rₕᵣ,color=:red)
    barplot!(ax2,w̃,R̃,color=:blue)
    barplot!(ax2,w̃,R̃ₕ,color=:green)
    barplot!(ax2,w̃,R̃ₕᵣ,color=:red)
    barplot!(ax3,R,color=:blue)
    barplot!(ax3,Rₕ,color=:green)
    barplot!(ax3,Rₕᵣ,color=:red)
    barplot!(ax4,R̃,color=:blue)
    barplot!(ax4,R̃ₕ,color=:green)
    barplot!(ax4,R̃ₕᵣ,color=:red)

    
    ax5 = Axis(f[2,1:2])
    phase_plot!(ax5,s)
    ax6 = Axis(f[2,3:4])
    incomes_plot!(ax6,s, order=false)
    
    Label(f[0,:], string(
        "N=",N,", K =",K,", r=",r,", p=",p,", ē= ",ē, 
        "\n wₒ: ",@sprintf("%.3f",findmin(wₒ)[1]),"-",@sprintf("%.3f",findmax(wₒ)[1]),
        ", q: ",@sprintf("%.3f",findmin(q)[1]),"-",@sprintf("%.3f",findmax(q)[1]),
        "\n w̃: ",@sprintf("%.3f",findmin(w̃)[1]),"-",@sprintf("%.3f",findmax(w̃)[1]),
        ", ū: ",@sprintf("%.3f",findmin(ū)[1]),"-",@sprintf("%.3f",findmax(ū)[1])
    ),fontsize=16,color=:black)
    

    display(f);
    #return s.final.p
end

#ushaped scenario

#q=0.1*range(-1,1,N).^2 .+ 0.05
#wₒ = default

# s=qwcovar(;N,q=0.3.*q,wₒ=0.3*wₒ,p=5)

#then change the multipler on both q and w to get various outcomes.