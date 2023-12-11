N=20
qmin=1/N
qmax=1/N
wmin=0.05
wmax=0.20

s=scenario(N=100;w=SED(min=wmin,max=wmax),q=SED(min=qmin,max=qmax),ē=1.0,r=1.0,K=1.0,p=5.0)

qmin=0.01
qmax=0.20
steps=40

for v in range(qmin,qmax,steps)
    f=martyPlot(scenario(;N,w=SED(min=wmin,max=wmax),q=SED(min=v,max=v),ē=1.0,r=1.0,K=1.0,p=5.0))
    display(f)
end

for v in range(qmin,qmax,steps)
    f=martyPlot(scenario(;N,w=SED(min=wmin,max=wmax),q=SED(min=qmin,max=v),ē=1.0,r=1.0,K=1.0,p=5.0))
    display(f)
end

# This keeps mean and varies spread
for v in range(-0.024,0.024,steps)
    f=martyPlot(scenario(;N,w=SED(min=wmin,max=wmax),q=SED(mean=0.025,spread=-v),ē=1.0,r=1.0,K=1.0,p=2.5))
    display(f)
end

for v in range(wmin,wmax,steps)
    f=martyPlot(scenario(;N,w=SED(min=v,max=v),q=SED(min=qmin,max=qmax),ē=1.0,r=1.0,K=1.0,p=5.0))
    display(f)
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

function figure2(;saveas="Figure_SED.png")
d=[scenario(w=SED(mean=0.3,spread=0.5,rand=true,distribution=:lognormal),q=SED(dependent=(w=-500.4,),mean=2.0,spread=-0.8,normalize=true, rand=true),p=100),scenario(w=SED(mean=0.5,spread=0.9,rand=true,distribution=:lognormal),q=SED(dependent=(w=-500.4,),mean=1.0,spread=-0.8,normalize=true, rand=true),p=100, color=colorant"forestgreen")]
d=d[2]
icons=false
f=Figure(resolution=(900,1000))
denseq=Axis(f[1,1], height=50)
densew=Axis(f[1,3], height=50)
hidespines!(denseq)
hidespines!(densew)
hidedecorations!(denseq)
hidedecorations!(densew)
xlims!(densew,0.0,1.0)
cumq=Axis(f[2,1], title="Extraction efficiency")
cumw=Axis(f[2,3], title="Alternative income")
xlims!(cumw,0.0,1.0)
w_q=Axis(f[2,2])
cumū=Axis(f[3,1], title="Cumulative Impact, ū")
cumw̃=Axis(f[3,3], title="Cumulative Incentive, w̃")
xlims!(cumw̃,0.0,1.0)
w̃_ū=Axis(f[3,2])
sustained=Axis(f[4,1], title="Sustained use isocline \nuₛ(y)=sum(u)=1-y")
phase=Axis(f[4,2], title="System dynamics \nPhase plot")
potential=Axis(f[4,3], title="Potential use isocline \nuₚ(y)=sum(w̃<y)")

SEDplot!(denseq,d,:q,cumsum,show_density=true;icons)
SEDplot!(densew,d,:w,cumsum,show_density=true;icons)
SEDplot!(cumq,d,:q,cumsum,show_density=false;icons)
SEDplot!(cumw,d,:w,cumsum,show_density=false;icons)
SEDplot!(w_q,d,:w,:q,show_density=false;icons)
SEDplot!(cumū,d,:ū,cumsum,show_density=false;icons)
SEDplot!(cumw̃,d,:w̃,cumsum,show_density=false;icons)
SEDplot!(w̃_ū,d,:w̃,:ū,show_density=false;icons)
phaseplot!(phase,d,show_trajectory=true, vector_field=false)
phaseplot!(sustained,d,show_trajectory=false, show_potential=false, show_attractor=false)
phaseplot!(potential,d,show_trajectory=false, show_required=false, show_attractor=false)
Label(f[1,2],"deterministic simple\nrand simple\nondimensional only\nrand complex",tellwidth=false)
Label(f[2,0],"Dimensional",tellwidth=true, tellheight=false,rotation=pi/2)
Label(f[3,0],"Non-dimensional",tellwidth=true, tellheight=false,rotation=pi/2)
Label(f[4,0],"System",tellwidth=true, tellheight=false,rotation=pi/2)
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