function get_best_target(s::Scenario;M=100)
    total::Array{Float64}=[]
    resource::Array{Float64}=[]
    gini::Array{Float64}=[]
    y::Array{Float64}=[]
    t=range(0.0,stop=1.0,length=M)
    for i in 1:M
        s.value=t[i]
        sim(s)
        
        push!(total,sum(s.total_revenue))
        push!(resource,sum(s.resource_revenue))
        push!(gini,s.gini)
        push!(y,s.y)
    end
    #id_total=t[argmax(total)],id_resource=t[argmax(resource)],id_ginnig=t[argmin(gini)],
    return (target=collect(t),total=total,resource=resource,gini=gini,y=y)
end


