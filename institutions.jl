function institutional_impact(S::Scenario;M=100, inst=1)
    s=deepcopy(S)
    total::Array{Float64}=[]
    resource::Array{Float64}=[]
    gini::Array{Float64}=[]
    I::Array{Float64}=[]
    y::Array{Float64}=[]
    t=range(0.0,stop=1.0,length=M)
    U=zeros(s.N,M)
    for i in 1:M
        s.institution[inst].value=t[i]
        sim!(s)
        
        push!(total,sum(s.total_revenue))
        push!(resource,sum(s.resource_revenue))
        push!(gini,s.gini)
        push!(y,s.y)
        U[:,i]=s.resource_revenue
        s.institution[inst].value=0
        du=zeros(s.N+3)
        dudt(du,vcat(s.u,s.y,0.0,s.ϕ),s,0.0)
        push!(I,sum(max.(0.0,du[1:s.N])))
    end

    #id_total=t[argmax(total)],id_resource=t[argmax(resource)],id_ginnig=t[argmin(gini)],
    return (target=collect(t),id_total=t[argmax(total)],id_resource=t[argmax(resource)],id_ginnig=t[argmin(gini)],total=total,resource=resource,gini=gini,I=I,y=y,U=U)
end

function plot_institutional_impact(o;weight=[1,1,1,1,1],s=scenario())
    weight=round.(weight, digits=4)
    w=o.resource.^weight[1].*o.total.^weight[2].*o.gini.^weight[3].*o.I.^weight[4].*o.y.^weight[5]
    opt=argmax(w)
    f=Figure(size=(800,700))
    t="hello"
    a=Axis(f[1,1:2], xticks=([],[]),yticks=([],[]),ylabel="normalized")
    a2=Axis(f[2,1:2], xticks=([],[]),yticks=([],[]),titlesize=20,ylabel="utility u(i)",title=L"$u_G(i)=R^{%$(weight[1])} T^{%$(weight[2])} G^{%$(weight[3])} I^{%$(weight[4])} Y^{%$(weight[5])}$")#L"Weighted goal function: $u(i)=R(i)^{%(string(wheight[1]))} $T"*string(wheight[2])*" G"*string(wheight[3])*" I"*string(wheight[4])*" Y"*string(wheight[5]))
    a3=Axis(f[3,1:2],xticks = ([10,90], ["Full Regulation", "Open Access"]),yticks = ([10,90], ["Low", "High"]),ylabel="alternative opportunities")
    a4=Axis(f[2,3])
    l2=lines!(a,o.target,o.total./maximum(o.total),label="Total Revenue", linewidth=3)
    l1=lines!(a,o.target,o.resource./maximum(o.resource),label="Resource Revenue", linewidth=3)
    l3=lines!(a,o.target,o.gini./maximum(o.gini),label="Gini", linewidth=3)
    l4=lines!(a,o.target,(o.I.-minimum(o.I))./maximum(o.I.-minimum(o.I)),label="Institutional Impact", linewidth=3)
    l5=lines!(a,o.target,o.y/maximum(o.y),label="Stock", linewidth=3)
    lines!(a,[o.target[opt],o.target[opt]],[0,1],color=:darkorange,linestyle=:dash)
    Legend(f[1,3],[l1,l2,l3,l4,l5],["Resource Revenue","Total Revenue","Gini","Institutional Coercion","Stock"],"Governance aspects",tellwidth=false,orientation = :vertical, halign=:left)
   
    lines!(a2,o.target,w./maximum(w),color=:darkorange, linewidth=3)
    lines!(a2,[o.target[opt],o.target[opt]],[0,1],color=:darkorange,linestyle=:dash)
    heatmap!(a3,o.U', colormap=:BuGn)
    Colorbar(f[3, 3], limits = (0, maximum(o.U)),label="Resource income", colormap = :BuGn,
    flipaxis = true, tellwidth=false, halign=:left)
    lines!(a3,[opt,opt],[0,100],color=:darkorange,linestyle=:dash)
    S=deepcopy(s)
    println(S)
    S.institution[1].value=o.target[opt]
    S.color=convert(HSL,colorant"darkorange")
    sim!(S)
    phaseplot!(a4,S,show_realized=true)
    S.institution[1].value=1.0
    S.color=convert(HSL,colorant"gray")
    sim!(S)
    phaseplot!(a4,S,show_realized=true)
    return f
end

abstract type Institution end

abstract type dynamicInstitution <: Institution end
abstract type staticInstitution <: Institution end
abstract type limitInstitution <: Institution end

function dynamic_institution(institution::dynamicInstitution,du,u,s,t)
    
    institution.fun(institution,du,u,s,t)
end


function dynamic_institution(institution::Union{limitInstitution,staticInstitution},du,u,s,t)
    return
end

function limit_institution(institution::limitInstitution,s,integrator)

    institution.fun(institution, integrator.du,integrator.u,s, integrator.t)
end

function limit_institution(institution::Union{dynamicInstitution,staticInstitution},s,integrator)
    return
end

function static_institution(institution::staticInstitution,s)
    institution.fun(institution,s)
end

function static_institution(institution::Union{limitInstitution,dynamicInstitution},s)
    return
end


function Base.show(io::IO, inst::Institution)
    typename = typeof(inst)
    fields = fieldnames(typename)
    println(io, "$(typename):")
    for field in fields
        value = getfield(inst, field)
        fieldtype = typeof(value)
        if value isa Function
            func_name = String(nameof(fieldtype))[2:end]
            println(io, "  $(field) (Function): $func_name")
        else
            println(io, "  $(field) ($(fieldtype)): $value")
        end
    end
end
