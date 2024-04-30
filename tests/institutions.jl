#=
open_access(inst,s)=return

function test(inst,s) s.aū=fill(1.2,s.N) end

test_inst=staticInstitution(0.0,1.0,(;a=1),test)

s=scenario(institution=[test_inst])

function PA(inst,s)
    s.dispersal=0.2
    s.protected=0.2
end

function protected_area_function(inst,s)
    s.dispersal=0.2
    s.protected=0.2
end

PA_inst=staticInstitution(0.0,1.0,(;a=1),PA)

s=scenario(institution=[PA_inst])

=#
mutable struct dynamic_permit_allocation <: limitInstitution
    criteria::Symbol
    reverse::Bool
    target::Symbol
    value::Float64
    control::Symbol
    fun::Function
end

function dyn_permits2(institution::dynamic_permit_allocation,du,u,s,t)
  
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

function dyn_permits3(institution::dynamic_permit_allocation3, du, u, s, t)
    # Calculate the number of allowed permit holders
    num_permits = Int64(round(institution.value * s.N))

    # Identify potential resource users
    potential_users = findall(u .> 0.0)

    # If there are more potential users than permits, we need to select permit holders
    if length(potential_users) > num_permits
        # Sort potential users based on the institution's criteria
        sorted_indices = sortperm(getfield(s, institution.criteria), rev=institution.reverse)

        # Find the indices of users who will be granted a permit
        permitted_indices = institution.reverse ? sorted_indices[end-num_permits+1:end] : sorted_indices[1:num_permits]

        # Update `u` to reflect that only permitted users can use the resource
        # All others are set to 0.0, indicating no usage
        u .= 0.0  # Assume no one is allowed to use the resource initially
        u[permitted_indices] .= u[potential_users]  # Re-allow usage for permitted users
    end
end


function dyn_permits(institution::dynamic_permit_allocation3,du,u,s,t)
    n=Int64(round(s.N*institution.value))
    id=findall(u[1:s.N].>0.0)
    l=length(id)-n
    V=zeros(s.N)
    vid=id[sortperm(getfield(s,institution.criteria)[id],rev=institution.reverse)[1:l]]
    q=1:s.N
    idq=q[q .∉ Ref(vid)] 
    u[idq].=0.0
end

s=scenario(q=SED(mean=1.0,sigma=0.2,random=false,normalize=true),institution=[dynamic_permit_allocation3(:q,true,:test,0.2,:value,dyn_permits2)])
s.q.random=true
dist!(s)

sim!(s)

struct equal_share_allocation <: limitInstitution
    criteria::Symbol
    threshold::Float64
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

s=scenario(q=SED(mean=1.0,sigma=0.2,random=false,normalize=true),institution=[equal_share_allocation(:w̃,0.0,false,:effort,0.2,:value,equal_share)])
s.q.random=true
dist!(s)

sim!(s)
phaseplot(s, show_realized=true)
#=
	if p.institution=="Tradable"
		if p.target=="yield"
			supply=max(0.0,p.value-sum(u)*y)
		else
			supply=max(0.0,p.value-sum(u))
		end
	        id=findall(dx[1:N].>0.0) # who wants to increase u => id
	
	         # available quotas, but in units of u
	        #demand=sum(max.(0.0,view(ū,id).-(view(u,id).+view(dx,id)))) # demand, as in intending to increase u
	        demand=sum(view(dx,id)) 
			if demand > supply # if demand is greater than supply, buyers have to share supply proportionally to their individual demand or willingness to pay.
	            dx[id].=supply.*view(dx,id)./demand
	        end  

        # else they can just do as they please, i.e. dudt is not adjusted

		# Dynamics of tradable quota price
	    @inbounds dx[N+2]= constrain(β*(demand -supply),ϕ,0.0,Inf64,dt) 
	end
    =#
    mutable struct tradable_use_rights_m <: dynamicInstitution
        criteria::Symbol
        threshold::Float64
        reverse::Bool
        target::Symbol
        value::Float64
        control::Symbol
        fun::Function
    end

    function trade_use_rights(institution::tradable_use_rights_m,du,u,s,t)
        
        if institution.target==:yield
            supply=max(0.0,institution.value-sum(u)*s.y)
            
        elseif institution.target==:effort
            
            supply=max(0.0,institution.value-sum(u))
        end
        
     
        id = findall((du[1:s.N] .> 0.0) .& ((u[1:s.N] ) .< s.ū)) #+ du[1:s.N]
        demand=sum(du[id]) 
       
        if demand > supply # if demand is greater than supply, buyers have to share supply proportionally to their individual demand or willingness to pay.
            
            du[id].=supply.*min(du[id],s.ū[id].-u[id])./demand
           
        end  
        du[s.N+3]= institution.threshold*(demand -supply)

    end

    s=scenario(q=SED(mean=1.0,sigma=0.2,random=false,normalize=true),institution=[tradable_use_rights_m(:w̃,0.05,false,:effort,0.1,:value,trade_use_rights)])
s.q.random=false
dist!(s)

sim!(s)
phaseplot(s,show_realized=true)

function figure_institutions(;s=scenario(q=SED(mean=1.5,sigma=0.0,random=false,normalize=true), color=:gray))
    # update!(s)
    # copy(s,(:q,(:mean,0.2)))
    dist!(s)
    sim!(s)
    f=Figure(size=(1200,800))
    permit_low_w=Axis(f[1,1])
    permit_high_w=Axis(f[1,2])
    equal_share_effort=Axis(f[2,1])
    equal_share_yield=Axis(f[2,2])
    tradable_effort=Axis(f[3,1])
    tradable_yield=Axis(f[3,2])
    protected_areas_1=Axis(f[1,3])
    price_tax_sub_1=Axis(f[2,3])
    effort_tax_sub_1=Axis(f[3,3])
    protected_areas_2=Axis(f[1,4])
    price_tax_sub_2=Axis(f[2,4])
    effort_tax_sub_2=Axis(f[3,4])
    #s.q.mean=1.0
    #dist!(s);sim!(s)
    phaseplot!(permit_low_w,s,show_realized=true)
    s1=scenario(q=SED(mean=1.5,sigma=0.0,random=false,normalize=true),institution=[dynamic_permit_allocation3(:q,true,:test,0.4,:value,dyn_permits2)], color=:orange)
    dist!(s1);sim!(s1)
    phaseplot!(permit_low_w,s1,show_realized=true, show_potential=false)
    phaseplot!(permit_high_w,s,show_realized=true)
    phaseplot!(equal_share_effort,s,show_realized=true)
    phaseplot!(equal_share_yield,s,show_realized=true)
    phaseplot!(tradable_effort,s,show_realized=true)
    phaseplot!(tradable_yield,s,show_realized=true)
    phaseplot!(protected_areas_1,s,show_realized=true)
    phaseplot!(price_tax_sub_1,s,show_realized=true)
    phaseplot!(effort_tax_sub_1,s,show_realized=true)
    phaseplot!(protected_areas_2,s,show_realized=true)
    so=scenario(q=SED(mean=0.5,sigma=0.0,random=false,normalize=true), color=:gray)
    dist!(so)
    sim!(so)
    
    phaseplot!(price_tax_sub_2,so,show_realized=true)
    phaseplot!(effort_tax_sub_2,so,show_realized=true)

    # Explicit show who wins and who looses
    # subsidize q, for all,high or low q
    # subsidize price, for all
    # table is to show which cases
    # heading: initial condition (over/under exploitation), intervention type (tradable, permits, price + effort tax/subsidy, protected area), scenarios (equal, linear, inequal poor), correlation (+/0/-)

    # outcomes revenues of 0) openaccess 1) fishery 2) total (%change) 3) gini (%change) 4) Picketty quartiles!? 5) stock

    # when q and w ar correlated then the following is true: xyz
    f

end



s=scenario(q=SED(mean=1.5,sigma=0.9,random=false,normalize=true),institution=[dynamic_permit_allocation(:q,true,:test,0.3,:value,dyn_permits2)], color=:orange)
dist!(s);sim!(s);o=institutional_impact(s); display(plot_institutional_impact(o,weight=[0,1,-0.5,0,0],s=s))
s=scenario(q=SED(mean=1.5,sigma=-0.9,random=false,normalize=true),institution=[dynamic_permit_allocation(:q,true,:test,0.3,:value,dyn_permits2)], color=:orange)
dist!(s);sim!(s);o=institutional_impact(s); display(plot_institutional_impact(o,weight=[0,1,-0.5,0,0],s=s))
s=scenario(q=SED(mean=1.5,sigma=0.9,random=false,normalize=true),institution=[dynamic_permit_allocation(:q,false,:test,0.3,:value,dyn_permits2)], color=:orange)
dist!(s);sim!(s);o=institutional_impact(s); display(plot_institutional_impact(o,weight=[0,1,-0.5,0,0],s=s))
s=scenario(q=SED(mean=1.5,sigma=-0.9,random=false,normalize=true),institution=[dynamic_permit_allocation(:q,false,:test,0.3,:value,dyn_permits2)], color=:orange)
dist!(s);sim!(s);o=institutional_impact(s); display(plot_institutional_impact(o,weight=[0,1,-0.5,0,0],s=s))

s=scenario(q=SED(mean=2.0,sigma=0.2,random=false,normalize=true),institution=[tradable_use_rights_m(:w̃,0.05,false,:effort,0.2,:value,trade_use_rights)])


s=scenario(q=SED(mean=2.0,sigma=0.2,random=false,normalize=true),institution=[])
