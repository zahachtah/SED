function midpoint(p1::Point2{Float64}, p2::Point2{Float64})
    return Point2((p1[1] + p2[1]) / 2, (p1[2] + p2[2]) / 2)
end

# Function to calculate the angle between two points
function anglep(p1::Point2{Float64}, p2::Point2{Float64})
    return atan(p2[2] - p1[2], p2[1] - p1[1])
end

# Function to get the midpoint and angle between two points
function midpoint_and_angle(p1::Point2{Float64}, p2::Point2{Float64})
    mid = midpoint(p1, p2)
    ang = angle(p1, p2)
    return mid, ang
end

g = DiGraph()
external=[:gender,:culture,:heritage]
D=Dict()
vars=vcat([:w, :q, :ē, :a, :p, :r, :K],external)
for i in 1:10
    add_vertex!(g)
    D[vars[i]]=i
end

    add_edge!(g, 1, 2)
    add_edge!(g, 1, 5)
    add_edge!(g, 2, 3)
    add_edge!(g, 1, 3)
    add_edge!(g, 2, 4)
    add_edge!(g, 4, 5)
    add_edge!(g, 5, 6)
    add_edge!(g, 5, 7)
    add_edge!(g, 7, 8)
    add_edge!(g, 9, 10)
    add_edge!(g, 4, 9)

    topological_sort_by_dfs(g)


    layout = Spring(; iterations=200)#SFDP(Ptype=Float32, tol=0.01, C=0.2, K=1)#Spring(; iterations=200)#Buchheim()#Spring(; iterations=200)#Buchheim()#Spring(; iterations=20)
    pos = layout(g)
    f=Figure()
    a=Axis(f[1:10,3:12], aspect=1)
    for p in edges(g)
        lines!(a,[pos[p.src][1],pos[p.dst][1]],[pos[p.src][2],pos[p.dst][2]], color=:gray)
        scatter!(a,midpoint(pos[p.src],pos[p.dst]),marker=:utriangle,markersize=10,rotations=anglep(pos[p.src],pos[p.dst])-pi/2,color=:gray)
    end
    scatter!(a,pos, markersize=5 .+5*(11 .-collect(1:10)), strokewidth=5, strokecolor=:white)
    hidespines!(a)
    hidedecorations!(a)
    for i in 1:10
        ai=Axis(f[i,1:2])
        hidedecorations!(ai)
        income_distributions(ai,s, show_text=false)
    end
    f

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


    N=10
    value=0.5
    n=Int64(round(N*value)) #target(t,u,p)=2
    u=0.1*collect(1:N).-0.1
    q=rand(N)

    #violation(t,u,p)
    A=u.>0.0 # should be u.>U
    id=findall(A)
    vn=length(id)-n
    V=zeros(N)
    vid=id[sortperm(q[id],rev=false)[1:vn]]
    V[vid]=u[vid]  # ? -U
    V

    # How to calculate rule violation under tradable individual use rights