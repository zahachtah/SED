#=

Consider this instead:

struct dynamic_permit_allocation <: limitInstitution
    params=NamedTuple()
end

function dyn_permits(institution::dynamic_permit_allocation,du,u,s,t)
    @unpack criteria, reverse, target, value, control, fun = institution.params

end

=#



# Permits or use rights:

mutable struct dynamic_permit_allocation <: limitInstitution
    criteria::Symbol
    reverse::Bool
    target::Symbol
    value::Float64
    control::Symbol
    fun::Function
end

function dyn_permits(institution::dynamic_permit_allocation,du,u,s,t)
  
    n=Int64(round(institution.value.*s.N)) # number of allowed permitholders (can we do this at scenario creation)
    id=findall(u.>0.0)      # get all who would like to use resource
    l=length(id)                  # number of potential resource users 
    if l>n  # if number of actors that want to use resource are more than number of permits 
        #println(p.target)
        if institution.reverse
            r=l-n+1:l   # select the permit holders (given to high w)
        else
            r=1:n # select the permit holders (given to low w)
        end
        q=sortperm(getfield(s,institution.criteria))
        idq=q[q .∉ Ref(id[r])] #checks if qdy is in id[r] and returns the indices of q that are not in id[r]
        u[idq] .= 0.0
    end
end

# Equal share


mutable struct equal_share_allocation <: limitInstitution
    criteria::Symbol
    reverse::Bool
    target::Symbol
    value::Float64
    control::Symbol
    fun::Function
end

function equal_share(institution::equal_share_allocation,du,u,s,t)
    n=sum(u.>0.0)
    if institution.target==:yield
        u[1:s.N].=ifelse.(u[1:s.N].>institution.value/u[s.N+1]/n, institution.value/u[s.N+1]/n , u[1:s.N] )
    elseif institution.target==:effort
        u[1:s.N].=ifelse.(u[1:s.N].>institution.value/n, institution.value/n , u[1:s.N] )
    end
end


# Protected area

mutable struct protected_area <: dynamicInstitution
    criteria::Symbol
    reverse::Bool
    target::Symbol
    value::Float64
    control::Symbol
    fun::Function
end

function equal_share(institution::equal_share_allocation,du,u,s,t)
    n=sum(u.>0.0)
    if institution.target==:yield
        u[1:s.N].=ifelse.(u[1:s.N].>institution.value/u[s.N+1]/n, institution.value/u[s.N+1]/n , u[1:s.N] )
    elseif institution.target==:effort
        u[1:s.N].=ifelse.(u[1:s.N].>institution.value/n, institution.value/n , u[1:s.N] )
    end
end