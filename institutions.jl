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
