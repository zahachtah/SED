
external=(gender=SED(min=0.0,max=1.0),culture=SED(min=0.0,max=1.0), heritage=SED(min=0.0,max=1.0),health=SED(min=0,max=1.0))

w=SED(dependent=(gender=0.02, heritage=-0.02),max=0.3,min=0.04,rand=true,normalize=true)# dependent=(gender=0.2,health=0.5),
q=SED(dependent=(w=200,gender=0.03, heritage=0.4),max=0.6,min=0.1,rand=true,normalize=true)#gender=0.6, heritage=.1,

s=scenario(N=100;external,w,q, color=colorant"steelblue")


M=Dict()
I=[:w,:q,:ē,:a,:p,:r,:K]
E=collect(keys(s.external))
g=DiGraph()

# For all internal, check if they have dependencies, if so add them to the graph and check they exist in external
for (i,k) in enumerate(vcat(I,E))
    add_vertex!(g)
    M[k]=i
    M[i]=k
end
# can probably do this in one pass  
for i in I
    if isa(getfield(s,i),SED) 
        N= keys(getfield(s,i).dependent)
        for n in N
            add_edge!(g, M[n], M[i])
        end
    end
end
# save the graph and the vertex names
is_cyclic(g)
topological_sort_by_dfs(g)
for i in topological_sort_by_dfs(g)
    if M[i] in I
        var=getfield(s,M[i])
        if isa(var,SED)
            if var.dependent!=nothing
                for d in keys(var.dependent)
                    if d in E 
                        var.data.+=getproperty(var.dependent, d).*getproperty(s.external,d)
                    else
                        println(var.data)
                        var.data.+=getproperty(var.dependent, d).*getproperty(s,d)
                        println(var.data)
                    end
                end
            end
        end 
    end
end

cor(s.w,s.q)


F=Figure()
A=Axis(F[2,1:2 ])
B=Axis(F[2,3:4 ], xlabel="w", ylabel="q")
C=Axis(F[1,1 ], xlabel="gender", ylabel="q")
D=Axis(F[1,2 ], xlabel="gender", ylabel="w")
E=Axis(F[1,3 ], xlabel="heritage", ylabel="q")
FF=Axis(F[1,4 ], xlabel="heritage", ylabel="w")
#SEDplot!(B,s,:w,:q)
scatter!(C,s.external.gender,s.q,markersize=5, color=:crimson)
scatter!(D,s.external.gender,s.w,markersize=5, color=:crimson)
scatter!(E,s.external.heritage,s.q,markersize=5, color=:crimson)
scatter!(FF,s.external.heritage,s.w,markersize=5, color=:crimson)
scatter!(B,s.w,s.q,markersize=5, color=:crimson)
phaseplot!(A,s, show_trajectory=true)
F
