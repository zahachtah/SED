constrain(du,u,minu,maxu,dt)=du.*dt.+u.<minu ? -u : du.*dt.+u.>maxu ? maxu-u : du

function dudt(dx,x,p,t)
    # extract the parameters from named tuple containers for simpler equation syntax
    dydt=p.sim.dydt # used when y is held constant
    N=p.N
	ū=p.ū.*p.aū
	w̃=p.w̃.*p.aw̃
	α=p.α
	#q=p.t
	β=p.β
	dt=p.sim.dt #parameters
    
    # extract the variables from state vector
    u=view(x,1:N)   # actions
    #y=mean(x[N+1:end-1]) # if one wants to use spatial models of resource dynamics 		
    y=x[N+1]  
	yp=x[N+2]      # resource level
	ϕ=x[N+3] 		#quota price

	# First get the non-institutional rate of change in u
	f=0.0
	d=0.2

	# NOTE NOTE NOTE: added 0.7 (f=0.3) to resource income calculation in scenarios.jl, change that

	# DO we need the dydt still? probably, for calculating attractor for fixed y
	
    @inline dx[1:N]=α.*(y*(1-p.protected).-w̃)
	dx[N+1]=dydt*(((1 -y)-sum(u)/(1-p.protected)) *y+((1-p.protected)!=0 ? p.protected/(1-p.protected)*p.dispersal*(yp-y) : 0))	
	dx[N+2]=dydt*(((1 -yp)) *yp+(p.protected!=0 ? (1-p.protected)/p.protected*p.dispersal*(y-yp) : 0))
end

function dudt_old(dx,x,p,t)
    # extract the parameters from named tuple containers for simpler equation syntax
    dydt=p.sim.dydt # used when y is held constant
    N=p.N
	ū=p.ū.*p.aū
	w̃=p.w̃.*p.aw̃
	α=p.α
	#q=p.t
	β=p.β
	dt=p.sim.dt #parameters
    
    # extract the variables from state vector
    u=view(x,1:N)   # actions
    y=x[N+1]  		# resource level
    ϕ=x[N+2] 		#quota price

	# First get the non-institutional rate of change in u

	
    @inline dx[1:N]=α.*(y.-w̃.-ϕ)
    # constrain dudt so that u can never leave the range [0.0, ū]
    # performance: if we do this in place we can increase speed
    # Also: this is done before TQ calc to ensure demand is zero when u is  at u\bar
 


    # PERMITS & PROPERTY RIGHTS
	
    if p.institution=="Permits" #if permits are used
        n=Int64(round(p.value.*N)) # number of allowed permitholders (can we do this at scenario creation)
        id=findall(u.+dx[1:N].>0.0)      # get all who would like to use resource
        l=length(id)                  # number of potential resource users 
        if l>n  # if number of actors that want to use resource are more than number of permits 
			#println(p.target)
            if p.target=="for high w̃" 
                r=l-n+1:l   # select the permit holders (given to high w)
            elseif p.target=="for low w̃"
                r=1:n # select the permit holders (given to low w)
            end
            q=1:N
            idq=q[q .∉ Ref(id[r])] #checks if qdy is in id[r] and returns the indices of q that are not in id[r]
            dx[idq] .= min.(0.0, -u[idq])
        end
    end
    # One can have quota shared equally among all actors or only among those who want to use resource

 
    if p.institution=="Shared"
        n=sum((u.+dx[1:N]).>0.0) # this ensures that only those who want to use resource get quota
		if p.target=="yield"
        	dx[1:N].-=ifelse.((u.+dx[1:N]).>p.value/y/n, (u.+dx[1:N]).-p.value/y/n , 0.0 )
		else
			dx[1:N].-=ifelse.((u.+dx[1:N]).>p.value/n, (u.+dx[1:N]).-p.value/n , 0.0 )
		end
    end

 
	# Why TQ after this line?
	# This is done before TQ calc to ensure demand is zero when u is  at u\bar
    @inline @inbounds dx[1:N].=constrain.(dx[1:N],u,0.0,ū,dt)
    #constrain!.(dx[1:N],u,0.0,ū,dt) Testing an inplace version with potentially less memory allocation

    #TRADABLE QUOTAS
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

    # The dynamic of the resource
    dx[N+1]=dydt*((1 -y)-sum(u)) *y
end

function stage_limiter!(u, integrator, p, t)
	U=zeros(Float64,p.N)
	# if u is regulated then
	#    calculate violation of u
	#    How are initial Quota distributed?
	#    depending on some parameter, e.g. status: w, incentive: w̃ or skill: q -> 0 or 1
	#    depending on share of Quota
	#    trading Quota

	#    change parameters

	#    change situation

    # Apply some constraint or modification at each stage

	#(:sol, :u, :du, :k, :t, :dt, :f, :p, :uprev, :uprev2, :duprev, :tprev, :alg, :dtcache, :dtchangeable, :dtpropose, :tdir, :eigen_est, :EEst, :qold, :q11, :erracc, :dtacc, :success_iter, :iter, :saveiter, :saveiter_dense, :cache, :callback_cache, :kshortsize, :force_stepfail, :last_stepfail, :just_hit_tstop, :do_error_check, :event_last_time, :vector_event_last_time, :last_event_error, :accept_step, :isout, :reeval_fsal, :u_modified, :reinitialize, :isdae, :opts, :stats, :initializealg, :differential_vars, :fsalfirst, :fsallast)

	# 1: calculate Use rights
	# U=Q/N; U=Q/y/N; U=fixed array; U=update array
	# 2: calculate violation min(0.0,u_i-U_i)
	#println(mod(t,365).<100 ? 0 : 1)
	p.institution!="Open" ? p.institution.use_rights(U,u,t,p) : U.=p.ū
	
	u[1:p.N].=ifelse.(u[1:p.N].<0.0,0.0,ifelse.(u[1:p.N].>U,U,ifelse.(u[1:p.N].>p.ū,p.ū,u[1:p.N])))
	#println([integrator.dt])
	#println(extrema(u[1:p.N]))
	# clamp!(u[1:p.N],0.0,p.ū)

end

"""
sim(p; tend=(0.0,2000.0), y0=1.0, dydt=1.0,u0=fill(0.0/p.N,p.N), p0=0.0,solution=false, terminate_steady_state=true)

Main function to run a simulation with parameters provided by a scenario.

### Arguments
- `p`: Scenario parameters given by a Scenario struct, i.e., scenario() for default
- `tend`: Tuple representing the start and end time for the simulation (default: (0.0,2000.0))
- `y0`: Initial resource level (default: 1.0)
- `dydt`: Initial rate of change of the resource (default: 1.0). Useful if one wants to check the outcome for a given resource set by y0, then set to 0.0.
- `u0`: Initial effort level array. By default, it is an array filled with zeros of size `p.N`.
- `p0`: Initial tradable quota price (default: 0.0)
- `solution`: Boolean value to indicate if the function should return the solution object. If false, the function returns the solution vector (default: false).
- `terminate_steady_state`: Boolean value to indicate if the function should terminate when reaching a steady state. If true, the function terminates when reaching a steady state (default: true).

### Output
`Simulation`: Returns a Simulation struct which consists of the following fields:
- `t`: Vector of time points at which the solution was calculated
- `y`: Vector of resource level at each time point
- `ϕ`: Vector of tradable quota prices at each time point
- `frac_u`: Vector of the fraction of total effort at each time point
- `u`: Matrix with individual effort level at each time point
- `final`: A nested struct containing several final state values including:
    + `u`: Mean effort level over the periodic part of the solution
    + `frac_u`: Fraction of total effort over the periodic part of the solution
    + `y`: Mean resource level over the periodic part of the solution
    + `ϕ`: Mean quota price over the periodic part of the solution
    + `period`: Indices of the periodic part of the solution
    + `time`: Time taken by the simulation
    + `p`: Scenario parameters
- `sol`: Solution object if the `solution` argument was set to true, otherwise nothing


    """
function sim!(p; tend=(0.0,2000.0), y0=1.0, dydt=1.0,u0=fill(0.0/p.N,p.N), p0=0.0,solution=false,terminate_steady_state=true)
	t0=time()
    N=p.N

    # sets up the problem,
    prob = ODEProblem(dudt,[u0;y0;y0;p0],tend,p)

    # solves the ODE
    #sol=solve(prob,adaptive=false, Euler(),saveat=0.1,callback=terminate_steady_state ? TerminateSteadyState(1e-6,1e-4) : nothing,dt=p.sim.dt)#  
	sol=solve(prob,SSPRK43(;stage_limiter!),reltol=1e-10,callback=terminate_steady_state ? TerminateSteadyState(1e-6,1e-4) : nothing)
	
	poa=deepcopy(p)
    poa.institution="OA"
    DUDT=zeros(N+3)
    dudt(DUDT,sol.u[end],poa,0.0)
	individual=zeros(N,length(sol.t))
    [individual[:,i]=sol.u[i][1:N] for i in 1:length(sol.t)]
	#check for periodicity
		yy=[u[N+1] for u in sol.u]
		period=1:length(yy)

		if var(yy)/mean(yy)>0.0001 && sol.t[end]==prob.tspan[2]
            
			try
				period=findPeriod(yy)
			catch
				period=1:length(yy)
			end
			#=U=mean(sol[1:N,period],dims=2)[:]
			Simulation(
        	sol.t,
        	[u[N+1] for u in sol.u],
        	[u[end] for u in sol.u],
        	[sum(u[findall(p.ū.>0.0)]./p.ū[findall(p.ū.>0.0)]./p.N) for u in sol.u],
        	individual,
			(u=mean(sol[1:N,period],dims=2)[:],up=sol[1:N,period],frac_u=sum(U./p.ū./p.N),y=mean(sol[N+1,period]),yp=sol[N+1,period],ϕ=mean(sol[end,period]),ϕp=sol[end,period],period=period,time=time()-t0,p=p,iu=DUDT[1:N]),
        	solution ? sol : nothing)=#

			
		else
			#=(
        	sol.t,
        	[u[N+1] for u in sol.u],
        	[u[end] for u in sol.u],
        	[sum(u[findall(p.ū.>0.0)]./p.ū[findall(p.ū.>0.0)]./p.N) for u in sol.u],# This makes sure that we are not accidentally dividing by zero! 
        	individual,
			(u=sol.u[end][1:N],frac_u=sum(sol.u[end][1:N]./p.ū./p.N),y=sol.u[end][end-1],ϕ=sol.u[end][end], period=1:length(sol.t),time=time()-t0,p=p,iu=DUDT[1:N]),
        	solution ? sol : nothing)=#
		end

		p.u=sol.u[end][1:N]
		p.U=sum(sol.u[end][findall(p.ū.>0.0)]./p.ū[findall(p.ū.>0.0)]./p.N)
	    p.y=sol.u[end][N+1]
	    p.ϕ=sol.u[end][end]
		p.t=sol.t
		p.t_u=[sol.u[t][i] for t in 1:length(sol.t), i in 1:p.N]#[u[1:N] for u in sol.u]
	    p.t_y=[u[N+1] for u in sol.u]
	    p.t_ϕ=[u[end] for u in sol.u]
		p.t_U=[sum(u[findall(p.ū.>0.0)]./p.ū[findall(p.ū.>0.0)]./p.N) for u in sol.u]
		c̃=0
		p.wage_revenue = (p.ū .- p.u) .* p.w̃.*p.r.*p.p.*p.K; 
        p.resource_revenue = p.u.*((p.y.*(1-p.protected)) .- c̃).*p.r.*p.p.*p.K;
        p.trade_revenue=(p.value./(p.y.*(1-p.protected))./p.N.-p.u).*p.ϕ.*p.r.*p.p.*p.K
        #R̃ₕᵣ= S.u.*(S.y .- S.w̃);
        p.total_revenue = p.wage_revenue .+  p.resource_revenue
		p.gini=gini(p.total_revenue)
	return p

end