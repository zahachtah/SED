function institutional_impact(S::Scenario;M=100, inst=1)
    s=deepcopy(S)
    total::Array{Float64}=[]
    resource::Array{Float64}=[]
    gini::Array{Float64}=[]
    I::Array{Float64}=[]
    y::Array{Float64}=[]
    t=range(0.0,stop=1.0,length=M)
    for i in 1:M
        s.institution[inst].value=t[i]
        sim!(s)
        
        push!(total,sum(s.total_revenue))
        push!(resource,sum(s.resource_revenue))
        push!(gini,s.gini)
        push!(y,s.y)
        s.institution[inst].value=0
        du=zeros(s.N+3)
        dudt(du,vcat(s.u,s.y,0.0,s.ϕ),s,0.0)
        push!(I,sum(max.(0.0,du[1:s.N])))
    end

    #id_total=t[argmax(total)],id_resource=t[argmax(resource)],id_ginnig=t[argmin(gini)],
    return (target=collect(t),id_total=t[argmax(total)],id_resource=t[argmax(resource)],id_ginnig=t[argmin(gini)],total=total,resource=resource,gini=gini,I=I,y=y)
end

function plot_institutional_impact(o;wheight=[1,1,1,1,1])
    f=Figure()
    a=Axis(f[1,1])
    scatter!(a,o.target,o.total./maximum(o.total),label="Total Revenue",color=:blue)
    scatter!(a,o.target,o.resource./maximum(o.resource),label="Resource Revenue",color=:red)
    scatter!(a,o.target,o.gini./maximum(o.gini),label="Gini",color=:green)
    scatter!(a,o.target,o.I./maximum(o.I),label="Institutional Impact",color=:black)
    scatter!(a,o.target,o.y./maximum(o.y),label="Stock",color=:gray)
    w=o.resource.^wheight[1].*o.total.^wheight[2].*o.gini.^wheight[3].*o.I.^wheight[4].*o.y.^wheight[5]
    scatter!(a,o.target,w./maximum(w),label="Weighted",color=:darkorange)
    println(argmax(w))
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
