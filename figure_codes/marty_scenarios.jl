N=20
qmin=1/N
qmax=1/N
wmin=0.05
wmax=0.20

#s=scenario(N=100;w=SED(min=wmin,max=wmax),q=SED(min=qmin,max=qmax),ē=1.0,r=1.0,K=1.0,p=5.0)

qmin=0.01
qmax=0.2
steps=40

for v in range(qmin,qmax,steps)
    s=scenario(;N,w=SED(min=wmin,max=wmax),q=SED(min=v,max=v),ē=1.0,r=1.0,K=1.0,p=5.0)
    dist!(s)
    sim!(s)
    display(phaseplot(s))
end

for v in range(qmin,qmax,steps)
    s=scenario(;N,w=SED(min=wmin,max=wmax),q=SED(min=qmin,max=v),ē=1.0,r=1.0,K=1.0,p=5.0)
    dist!(s)
    sim!(s)
    display(phaseplot(s))
end

function plot_incentive_shift(;steps=100,N=100,rn=false, distribution=Uniform, plotit=false)
wmin=0.05*10
wmax=0.10*10
qmin=0.01*20
qmax=0.2*20
U=zeros(N,steps)
S=zeros(steps)
T=zeros(steps)
R=zeros(steps)
G=zeros(steps)

for (i, v) in enumerate(range(qmin, stop=qmax, length=steps))
    sw=(wmax-wmin)/N
    iw=wmin-sw
    sq=((qmax-v)-v)/N
    iq=v-sq

    s=scenario(;N,w=SED(min=wmin,max=wmax, normalize=true, random=rn, distribution=distribution),q=SED(min=v,max=qmax-v,normalize=true, random=rn,),ē=1.0,r=1.0,K=1.0,p=5.0)
    dist!(s)
    sim!(s, tend=(0.0,20000))
    id=sortperm(s.w̃)
    U[:,i]=s.u#[id]
    
    T[i]=sum(s.total_revenue)
    R[i]=sum(s.resource_revenue)
    G[i]=s.gini
    A=diff(s.w).*s.q[1:(end-1)].-diff(s.q).*s.w[1:(end-1)]
    S[i]=median(A)
    if plotit==true
        f=Figure()
        a1=CairoMakie.Axis(f[1,1],title="$(round(sq*iw-sw*iq,digits=5)) ")   #q=qmin=$(round(v,digits=3)), qmax=$(round((qmax-v),digits=3))")
        a2=CairoMakie.Axis(f[1,2])
        a3=CairoMakie.Axis(f[2,2])
        a4=CairoMakie.Axis(f[3,1])
        a5=CairoMakie.Axis(f[2,1], ylabel=L"$f^'_w f_q - f^'_q f_w$")
        ylims!(a1,(0.0,qmax/N))
        #ylims!(a4,(0.0,1.0))
            
            lines!(a5,[1,length(A)],[0,0],color=:gray)
            
        scatter!(a5,A, color=[a>=0.0 ? :green : :red for a in A], markersize=4)
        
        hideydecorations!(a5, label=false)
        hidespines!(a5)
        SEDplot!(a1,s,:id,:w)
        SEDplot!(a1,s,:id,:q, color=:steelblue)
        SEDplot!(a4,s,:id,:w̃)
        SEDplot!(a4,s,:id,:ū, color=:steelblue)
        phaseplot!(a2,s, show_exploitation=false)
        incomes!(a3,s)
        display(f)
    end

end
ff=Figure()
aa=CairoMakie.Axis(ff[1,1], ylabel="Actor id",title="Incentive shift of resource use, distribution: "*string(distribution))
aa2=CairoMakie.Axis(ff[2,1], ylabel="Revenue & Gini", xlabel=L"average $f^'_w f_q - f^'_q f_w$")
linkxaxes!(aa, aa2)
hidexdecorations!(aa)
heatmap!(aa,S,1:N,U',colormap=:BuGn)
l1=lines!(aa2,S,T, label="Total Revenue", color=:blue)
l2=lines!(aa2,S,R, label="Resource Revenue", color=:red)
l3=lines!(aa2,S,G, label="Gini", color=:green)
Legend(ff[3,1],[l1,l2,l3],["Total Revenue","Resource Revenue","Gini"],orientation=:horizontal)

save("graphics/incentive_shift_"*string(distribution)*".png",ff)
display(ff)
end

for v in range(qmin,qmax,steps)
   println((min=v,max=qmax-v))
end

# This keeps mean and varies spread
for v in range(-0.024,0.024,steps)
    s=scenario(;N,w=SED(min=wmin,max=wmax),q=SED(mean=0.025,sigma=-v),ē=1.0,r=1.0,K=1.0,p=5.0)
    dist!(s)
    sim!(s)
    display(phaseplot(s))
    #f=martyPlot(scenario(;N,w=SED(min=wmin,max=wmax),q=SED(mean=0.025,spread=-v),ē=1.0,r=1.0,K=1.0,p=2.5))
    #display(f)
end

for v in range(wmin,wmax,steps)
    s=scenario(;N,w=SED(min=v,max=v),q=SED(min=qmin,max=qmax),ē=1.0,r=1.0,K=1.0,p=5.0)
    dist!(s)
    sim!(s)
    display(phaseplot(s))

   # f=martyPlot(scenario(;N,w=SED(min=v,max=v),q=SED(min=qmin,max=qmax),ē=1.0,r=1.0,K=1.0,p=5.0))
    #display(f)
end




s=scenario(;N=100,w=SED(min=wmin/5,max=wmax/15),q=SED(mean=2.0,spread=1.9, normalize=true),institution="TQ",ē=1.0,r=1.0,K=1.0,p=4.5)
scatter(s.w̃,s.ū,markersize=5, color=:crimson)

I=["PLL","PHL","EC","TQ"]

f=Figure()
phase=Axis(f[2,1])
total=Axis(f[1,1], title="Total Income", xlabel="0= full regulation, 1=no regulation")
ylims!(total,(0.0,nothing))
resource=Axis(f[1,2], title="Resource Income", xlabel="0= full regulation, 1=no regulation")
Gini=Axis(f[2,2], title="Gini", xlabel="0= full regulation, 1=no regulation")
phaseplot!(phase,s)


L=[]
for v in I
    s.institution=v
    d=get_best_target(s,M=100)
    z=lines!(total,d.target,d.total, markersize=3)
    lines!(resource,d.target,d.resource, markersize=3)
    lines!(Gini,d.target,d.gini, markersize=3)
    push!(L,z)
end
Legend(f[0,1:2],L,I,orientation=:horizontal)
f

scatter(s.w̃,s.ū,markersize=5, color=:crimson)

function figure2(;saveas="Figure_SED.png", show_density=false)
d=[scenario(w=SED(mean=0.3,spread=0.5,rand=true,distribution=:lognormal),q=SED(dependent=(w=-500.4,),mean=2.0,spread=-0.8,normalize=true, rand=true),p=100),scenario(w=SED(mean=0.5,spread=0.9,rand=true,distribution=:lognormal),q=SED(dependent=(w=-500.4,),mean=1.0,spread=-0.8,normalize=true, rand=true),p=100, color=colorant"forestgreen")]
d=d[2]
icons=false
f=Figure(resolution=(900,1000))
if show_density
    denseq=Axis(f[1,1])
    densew=Axis(f[1,3])
    hidespines!(denseq)
    hidespines!(densew)
    hidedecorations!(denseq)
    hidedecorations!(densew)
    xlims!(densew,0.0,1.0)
end

cumq=Axis(f[1,1], title="Extraction efficiency")
cumw=Axis(f[1,3], title="Alternative income")
xlims!(cumw,0.0,1.0)
w_q=Axis(f[1,2], title="Covariances")
cumū=Axis(f[2,1], title="Cumulative Impact, ū")
cumw̃=Axis(f[2,3], title="Cumulative Incentive, w̃")
xlims!(cumw̃,0.0,1.0)
w̃_ū=Axis(f[2,2])
sustained=Axis(f[3,1], title="Sustained use isocline")
phase=Axis(f[3,2], title="System dynamics \nPhase plot")
potential=Axis(f[3,3], title="Potential use isocline")
hidespines!(cumq)
hidespines!(cumw)
hidespines!(w_q)
hidespines!(cumū)
hidespines!(cumw̃)
hidespines!(w̃_ū)
hidespines!(sustained)
hidespines!(phase)
hidespines!(potential)
if show_density
SEDplot!(denseq,d,:q,cumsum,show_density=true;icons)
SEDplot!(densew,d,:w,cumsum,show_density=true;icons)
end
SEDplot!(cumq,d,:q,cumsum,show_density=false;icons)
SEDplot!(cumw,d,:w,cumsum,show_density=false;icons)
SEDplot!(w_q,d,:w,:q,show_density=false;icons)
SEDplot!(cumū,d,:ū,cumsum,show_density=false;icons)
SEDplot!(cumw̃,d,:w̃,cumsum,show_density=false;icons)
SEDplot!(w̃_ū,d,:w̃,:ū,show_density=false;icons)
phaseplot!(phase,d,show_trajectory=true, vector_field=false)
phaseplot!(sustained,d,show_trajectory=false, show_potential=false, show_attractor=false)
phaseplot!(potential,d,show_trajectory=false, show_required=false, show_attractor=false)
#Label(f[1,2],"deterministic simple\nrand simple\nondimensional only\nrand complex",tellwidth=false, tellheight=true)
Label(f[1,0],"Dimensional",tellwidth=true, tellheight=false,rotation=pi/2)
Label(f[2,0],"Non-dimensional",tellwidth=true, tellheight=false,rotation=pi/2)
Label(f[3,0],"System",tellwidth=true, tellheight=false,rotation=pi/2)
saveas!="" ? save(saveas,f) : nothing
f
end

with_theme(figure2, theme_light())
# CREATE LOGNORMAL WITH FIXED INTERVAL?


function figureDiversity(;saveas="Figure_Diversity.png")
    f=Figure()
    a11=Axis(f[1,1])
    a21=Axis(f[2,1])
    a12=Axis(f[1,2])
    a22=Axis(f[2,2])
    a13=Axis(f[1,3])
    a23=Axis(f[2,3])
    a14=Axis(f[1,4])
    a24=Axis(f[2,4])
    a15=Axis(f[1,5])
    a25=Axis(f[2,5])
    s=scenario(w=SED(mean=0.5,spread=1.0),ē=SED(mean=0.5,spread=1.0, rand=true),q=SED(mean=0.5,spread=1.0, rand=true,distribution=:lognormal))
    SEDplot!(a11,s,:id,:w)
    SEDplot!(a12,s,:id,:ē)
    SEDplot!(a13,s,:w,:w, show_density=true)
    SEDplot!(a14,s,:w,cumsum)
    SEDplot!(a14,s,:ē,cumsum)
    f

end

figureDiversity()


f=Figure()
a=Axis(f[1,1], xlabel="q")
Q=range(0.001,stop=0.005,length=100)
T=[]
R=[]
G=[]
Y=[]
M=zeros(100,100)
qq=vcat(fill(0.001,50),fill(0.02,50))
for i =1:100
    s=scenario(;N=100,p=4,w=SED(min=0.02,max=0.05),q=SED(mean=0.02,spread=-1.9*Q[i], rand=false,distribution=:linear))
    push!(T,sum(s.total_revenue))
    push!(R,sum(s.resource_revenue))
    push!(G,sum(s.gini))
    push!(Y,s.y)
    M[i,:]=s.total_revenue
end
scatter!(a,Q,Float64.(Y))
scatter!(a,Q,Float64.(R))
scatter!(a,Q,(Float64.(T).-minimum(T))./maximum(Float64.(T).-minimum(T)))
heatmap!(a,M)
f



wmin=0.05*10
wmax=0.10*10
qmin=0.01*20
qmax=0.2*20
steps=100


for (i, v) in enumerate(range(qmin, stop=qmax, length=steps))
 println((min=v,max=qmax-v))
end