mutable struct Scenario
    N
    external
    w
    q
    ē
    a
    r
    K
    p
    w̃
    ū
    α
    u
    U
    y
    ϕ
    t
    t_u
    t_U
    t_y
    t_ϕ
    total_revenue
    resource_revenue
    wage_revenue
    trade_revenue
    gini
    institution
    target
    signal
    β
    sim
    label
    image
    caption
    color
end
"""
    scenario(;N=100, external=Dict(), ē=SED(min=1.0,max=1.0), q=SED(min=1.0/N,max=1.0/N),
             a=SED(min=1.0,max=1.0), w=SED(min=0.1/N,max=0.9/N), r=1.0, K=1.0, p=1.0,
             w̃=nothing, ū=nothing, α=nothing, institution="OA", β=0.0 (conditional),
             target=1.0, signal="effort", ts=0.0, ū0=Array of zeros, y0=1.0, dydt=1.0,
             dt=0.01, label="", image="", caption="", color=nothing, simulate=true)

Simulates a scenario based on various parameters. The function adjusts these parameters and visualizes the outcomes. It is designed to work with a range of inputs, including basic dimensionalized and non-dimensionalized parameters, institutional parameters, and simulation parameters.

# Basic dimensionalized parameters
- `N::Int`: Number of entities or units in the simulation (default: 100).
- `external::NamedTuple`: External parameters provided as a dictionary (default: empty dict).
- `ē::SED`: Basic dimensionalized parameter (default: SED(min=1.0, max=1.0)).
- `q::SED`: Another basic dimensionalized parameter (default: SED(min=1.0/N, max=1.0/N)).
- `a::SED`, representing the efficiency of the technology
- `w::SED`, 
- `r::Float64`, 
- `K::Float64`, 
- `p::Float64`: 

# Basic non-dimensionalized parameters
- `w̃::Union{Float64,Nothing}`, The incentive ratio
- `ū::Union{Float64,Nothing}`, The impact ratio
- `α::Union{Float64,Nothing}`: The rate ratio

# Institutional parameters
- `institution::String`: Type of institution (default: "OA").
- `β::Float64`: Institutional parameter, conditional based on the institution type (default: 0.05 for "TQ", else 0.0).
- `target::Float64`, `signal::String`: Institutional parameters (default: target=1.0, signal="effort").

# Simulation parameters
- `ts::Float64`, 
- `ū0::Array{Float64,1}`, 
- `y0::Float64`, 
- `dydt::Float64`, 
- `dt::Float64`: Simulation parameters.

# Visualization parameters
- `label::String`, `image::String`, `caption::String`: Visualization parameters (default: empty strings).
- `color::Union{HSL,Colorant,String,Symbol}`: Color for visualization (default: none) converted to.
- `simulate::Bool`: Flag to indicate if simulation should be executed (default: true).

# Returns
- `S`: A `Scenario` object containing the results of the simulation.

# Examples
```julia
scenario_result = scenario(N=200, institution="TQ", simulate=true)
"""
function scenario(;
    # basic dimensionalized parameters
    N::Int=100,
    external=(;),
    ē=SED(min=1.0,max=1.0),
    q=SED(min=1.0/N,max=1.0/N),
    a=SED(min=1.0,max=1.0),
    w=SED(min=0.1/N,max=0.9/N),
    r=1.0,
    K=1.0,
    p=1.0,
    # basic non-dimensionalized parameters, if set these override dimensionalized parameters
    w̃=nothing,
    ū=nothing,
    α=nothing,
    # institutional parameters
    institution::String="OA",
    β::Float64=institution=="TQ" ? 0.05 : 0.0,
    target::Float64=1.0,
    signal::String="effort",
    #simulation parameters
    ts::Float64=0.0,
    ū0::Array{Float64,1}=fill(0.0,N),
    y0::Float64=1.0,
    dydt::Float64=1.0,
    dt::Float64=0.01,
    # visualzaion parameters
    label::String="",
    image::String="",
    caption::String="",
    color::Union{Colorant,Nothing}=nothing,
    simulate::Bool=true
)

    if external!=nothing
        Keys=collect(keys(external))
        for k in Keys
            if isa(external[k],SED)
                dist!(external[k],N)
            end
        end
    end

    has_dependencies=sum([isa(var,SED) ? length(var.dependent)>0 : false for var in [w,q,ē,a,p,r,K]])>0

    if  false
        g = DiGraph()
        add_vertex!(g) # for w
        add_vertex!(g) # for q
        add_vertex!(g) # for ē
        add_vertex!(g) # for a
        add_vertex!(g) # for p
        add_vertex!(g) # for r
        add_vertex!(g) # for K
        for i in eachindex(external)
            add_vertex!(g) # for w
        end
        for (j,v) in enumerate([w,q,ē,a,p,r,K])
            n=isa(v,SED) ? length(v.dependent) : 0
            for i in 1:n
                add_edge!(g, v.dependent[i][1], v)
            end
        end

    else
        dist!(w,N)
        dist!(q,N)
        dist!(ē,N)
        dist!(a,N)
        dist!(p,N)
        dist!(w̃,N)
        dist!(ū,N)
        dist!(α,N)
        dist!(r,N)
        dist!(K,N)
    end
	
	w̃==nothing ? w̃=SED(data=w./(K.*p.*q)) : isa(w̃,SED) ? w̃=dist!(w̃,N) : nothing
	ū==nothing ? ū=SED(data=ē.*q./r) : isa(ū,SED) ? ū=dist!(ū,N) : nothing
	α==nothing ? α=SED(data=(a.*p.*K.*q)./r) : isa(α,SED) ? α=dist!(α,N) : nothing
	
    # We just need a good recalc method to be able to adjust e.g. PA dependence!

    if institution=="PA"
        w̃=w̃./max(0.001,(1-(1-target))) # to avoid dividing by zero
        ū=ū./(1+(1-target))
        q_sum=sum(q)  # this needed?
    end

	color=color==nothing ? colorant"crimson" : color
	if isa(color,RGB)
		color=convert(HSL,color)
	end
	if isa(color,String)
		color=convert(HSL,parse(Colorant, color))
	end
		if isa(color,Symbol)
		color=convert(HSL,parse(Colorant, string(color)))
	end
	
	s=(N,
    external,
	w,
	q,
	ē,
	a,
	r,
	K,
	p,
	w̃,
	ū,
	α,
	u=[],
	U=0,
	y=0.0,
	ϕ=0.0,
	t=[],
	t_u=[],
	t_U=[],
	t_y=[],
	t_ϕ=[],
	total_revenue=[],
	resource_revenue=[],
	wage_revenue=[],
    trade_revenue=[],
	gini=0,
	institution,
	target,
	signal,#or yield
	β,
	sim=(;ū0,y0,dt,dydt),
	label,
	image,
	caption,
	color)

	S= simulate ? sim(Scenario(s...)) : Scenario(s...)
    if simulate
        #non-dimensional revenues
        c̃=0 #Yo, add c to scenario!
        S.wage_revenue = (S.ū .- S.u) .* S.w̃; 
        S.resource_revenue = S.u.*(S.y .- c̃);
        S.trade_revenue=(S.target./S.y./S.N.-S.u).*S.ϕ
        #R̃ₕᵣ= S.u.*(S.y .- S.w̃);
        S.total_revenue = S.wage_revenue .+  S.resource_revenue
        
    end
    
	return S
	
	#Scenario(N,w,q,ē,a,r,K,!isa(p,Array) ? fill(p,N) : p,w̃,ū,ū_sum,α,institution,T,t,target,β,ū0,y0,dt,dydt,label,image,caption,color)

end

function inputs(s::Scenario)
    println("N: ", s.N)
    isempty(s.external) ? nothing : println("external: ", s.external)
    println("w: ", isa(s.w,Array) ? "["*string(round(maximum(s.w), digits=3))*"..."*string(round(minimum(s.w), digits=3))*"]" : s.w)
    println("q: ", s.q)
    println("ē: ", s.ē)
    println("a: ", s.a)
    println("r: ", s.r)
    println("K: ", s.K)
    println("p: ", s.p)

end

function outputs(::Scenario)
    println("Outputs:")
end

function settings(::Scenario)
    println("Settings:")
end

function randomize!(::Scenario)
    isa(s.w,SED) ? dist!(s.w,s.N) : nothing
    isa(s.ē,SED) ? dist!(s.ē,s.N) : nothing
    isa(s.q,SED) ? dist!(s.q,s.N) : nothing
    isa(s.p,SED) ? dist!(s.p,s.N) : nothing
    isa(s.a,SED) ? dist!(s.a,s.N) : nothing
    isa(s.K,SED) ? dist!(s.K,s.N) : nothing
    isa(s.r,SED) ? dist!(s.r,s.N) : nothing
end
    


function dependencies(external, w, q, ē, a, p, r, K)
    # Initialize the directed graph with no vertices
    g = SimpleDiGraph()
    
    # Create a mapping from variable names to graph vertices
    var_to_vertex = Dict{Symbol, Int}()

    # Helper function to add vertices and dependencies
    function add_dependencies!(g, var_to_vertex, var_name, var)
        # Add vertex for the variable and update the mapping
        var_to_vertex[var_name] = add_vertex!(g)
        if isa(var, SED) && !isempty(var.dependent)
            for dep in var.dependent
                dep_name, _ = dep
                add_edge!(g, var_to_vertex[dep_name], var_to_vertex[var_name])
            end
        end
    end
    
    # Add internal variables first
    for (var_name, var) in zip([:w, :q, :ē, :a, :p, :r, :K], [w, q, ē, a, p, r, K])
        add_dependencies!(g, var_to_vertex, var_name, var)
    end
    
    # Now add external variables
    for (name, var) in external
        add_dependencies!(g, var_to_vertex, name, var)
    end
    
    # Check for cycles which would indicate circular dependencies
    if is_cyclic(g)
        error("Circular dependency detected.")
    end
    
    # Perform topological sort to get an evaluation order
    topological_order = topological_sort_by_dfs(g)

    # Map the vertex numbers back to variable names for readability
    variable_order = []
    for i in topological_order
        variable_name = findfirst(==(i), collect(values(var_to_vertex)))
        if isnothing(variable_name)
            continue  # or handle the error according to your requirements
        end
        push!(variable_order, collect(keys(var_to_vertex))[variable_name])
    end
    
    return variable_order
end

