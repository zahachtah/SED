# Todo:

1) make sure getBestInst works and add a general goal function with defaults
2) Make it easier to update SED parameters



The thing about diversity

set w\tilde u\bar with SED

set w\tilde u\bar with data -> SED.data (distribution=manual) (!! no SED?!!)

set w\tilde u\bar with external

set dimensional with SED -> set w\tilde u\bar -> SED.data (distriution=derived)

recalc!() know graph order


you can set data, you can derive data, and you can make data from a distribution

you set and derive data before you call dist!

for external you do that, for w\tilde   you calculate those
-> if r K q are not nothing && w\tilde has no data then derive?

Use rights (how much to use)
infrastructure regulations (what to use)
economic incentives (how much)
protected area (where to use, space, 100 n resource)
closures (when to use, time)
development (changing incentive structures)

make n-dimensional resource? can use N+1:end-1!
```julia
struct institution
    type::String # 
    target::Union{Float64,Int64}
    presim::Function
    incentives_and_impact::Function
    use_rights::Union{Function,Array{Float64}}
    response::Function #compliance
end

# Use rights
function use_rights_effort!(U,u,t,p)
    U=target/p.N
end

function use_rights_yield!(U,u,t,p)
    U=target/u[end-1]/p.N
end

function use_rights_free_permit!(U,u,t,p)
    U=ifelse.(p.w.>0.3,p.ū,0)  
end

function use_rights_shared_quota_permit!(U,u,t,p)
    U=ifelse.(p.w.>0.3,target/u[end-1]/sum(p.w.>0.3),0)  
end

# Infrastructure
function limited_gear(p)
    aw̃=
    aū=
end

# Economic incentives
function ()
cost of q?
royalties
price adjustments
end 

# Protected area
function limited_gear(p)
    aw̃=
    aū=
end

# Development
function increased_w()
    # add this to 
    p.aw̃.*x t
end
```
today:
- [ ] implement new institutions
- [ ] recalc with changed parameters
- [ ] new stage limit solver!
- [ ] make vector field actually use a sim


Other
- [ ] Seems the vector_field is not spot on compared to the trajectory. review this!
- [X] LogNormal distributions both with rand and ordered.
- [ ] Decide how to implement PA (in sim,deriv or scenario, and if scenario where to keep original values of K and r?)
- [ ] implement PA, subsidy and tax on different targets!
- [ ] implement reset scenario
- [ ] make best institution part of Scenario object
- [ ] Single case fig6
- [ ] optionally simplify fig6
- [ ] Dimensional revenue going to solve the comparison problem??
- [x] get_best_target function
- [x] get_best_institution function
- [ ] Next thing: add the dependency test into scenarios (as function?) so that dist can be called in the right order!
- [ ] pretty dependency plot
- [ ] Fix periodicity detection
- [x] change PLL to PLw, i.e. permits for low w...etc
- [x] only for N=50 the target institution matches..... (bug in EC and TQ, fixed)


### NOTE NOTE NOTE !!!!
TO ALLOW PLOTTING AGAINST EXTERNAL VARIABLES:
one could have s1 and s2 here and assign s1=s if v1 in internal variables and s1=s.external if v1 in external variables!
### NOTE NOTE NOTE !!!!