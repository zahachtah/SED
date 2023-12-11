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