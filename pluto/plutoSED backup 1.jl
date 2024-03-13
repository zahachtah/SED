### A Pluto.jl notebook ###
# v0.19.36

using Markdown
using InteractiveUtils

# ╔═╡ 427b27e6-7a74-11ee-37c9-732e5bcb9cc6
begin
	using Colors, Statistics, OrdinaryDiffEq, Distributions,CairoMakie, FileIO, Graphs, Random, KernelDensity, ColorSchemes, NetworkLayout
using DiffEqCallbacks: TerminateSteadyState
using Base: @kwdef
import Base: show
end

# ╔═╡ e7cdb1bc-d09c-477f-81c5-1d5fd73ea939
html"<button onclick='present()'>present</button>"

# ╔═╡ c3ae57f5-ad35-4ab5-8d52-21a2d42e2a17


# ╔═╡ 514d39b5-9235-4ef5-8de9-f5b6aa584f4f
constrain(du,u,minu,maxu,dt)=du.*dt.+u.<minu ? -u : du.*dt.+u.>maxu ? maxu-u : du

# ╔═╡ e4a270e2-16f4-4864-b082-9038ac654501
md"
* change!(Scenario,e=1)
* copy(Scenario,e=0.2)
* FIX THE LOGNORMAL ORDERED DISTRIBUTION!
* Should PA have a vertical institutional target?
* Fix phaseplot to export legend info
* Institutional impact with dark point inside?? doesn't work as supposed
* vector field is off
* Allow for Uniform(a+x,a-x), not just Uniform(a-x,a+x), i.e. import Uniform and override
* constrain distributions min, mean etc...
"

# ╔═╡ a439ee56-2ec6-4e76-a2af-1f6a58e8bea2
md"
## Distributions
A primary goal of this framework is to look at distributions. To fascilitate the transition between theoretical and empirical exploration we provide both random as well as ordered distributions. This framework depends on Distributions.jl and thus can access all the distributions of that package. Here we will only examplify with `Uniform` and `LogNormal`. In addition to Distributions.jl's statistical distribution we have added some utility distributions, i.e. `Constant` and `Shared`

* rand(Constant(v),N) = order(Constant(v),N) = [v,v,v,.....,v] of N length
* rand(Shared(v),N) = order(Shared(v),N) = [v/N,v/N,v/N,.....,v/N] of N length
* rand(Uniform(min,max),N) = [rand(min,max),rand(min,max),rand(min,max),rand(min,max),....,rand(min,max)] of N length
* order(Uniform(min,max),N) = range(min,max,N)
* order(LogNormal(min,max),N) = ordered distribution with a LogNormal density (distances)


FIX THE LOGNORMAL ORDERED DISTRIBUTION!
"

# ╔═╡ 6933c920-fcf9-4b15-904b-7df3d97687d3
md"
Realized fraction users

$fU(y)_{realized}=\frac{1}{N}\sum_{i}^N{\color{steelblue}\frac{u_i}{\bar{u}_i}}\cdot \begin{cases} 
1 & \text{if } \color{crimson}y > w_i \\
0 & \text{otherwise}
\end{cases}$

Potential fraction users

$fU(y)_{potential}=\frac{1}{N}\sum_{i}^N{\begin{cases} 
1 & \text{if } \color{crimson}y > w_i \\
0 & \text{otherwise}
\end{cases}}$

Sustained

$U_{sustined}(y)=fU(y)_{realized}==(1-y)$



A general definition of sustained use e.g.

$\frac{dy}{dt}=f_y(y,u)$

e.g. 

$f_y(y,u)=(1-y)$

$u(y) \text{ such that } f_y(y, u(y)) = 0$

$U_{\text{sustained}}(y) \equiv fU(y)_{\text{realized}} \quad \text{such that} \quad fU(y)_{\text{realized}} = f_y(y,u)=0$

$U_{\text{sustained}}(y) = fU(y) \quad \text{where} \quad fU(y)_{\text{realized}} = (1-y)$


Fraction realized impact

$fE(y)_{realized}=\frac{1}{\sum{\bar{u}}}\sum_{i=1}^N{\color{steelblue}u_i \color{white}\cdot \begin{cases} 
1 & \text{if } \color{crimson} \: y^* > w_i \\
0 & \text{otherwise}
\end{cases}}$

Realized impact

$E(y)=\sum_{i=1}^N{\color{steelblue}u_i \color{white}\cdot \begin{cases} 
1 & \text{if } \color{crimson} \:  y^* > w_i \\
0 & \text{otherwise}
\end{cases}}$



but note that in the algorithm we check that all $\bar{u}_i$ are positive before dividing
"

# ╔═╡ f945534a-5aa3-4b61-8f21-065dac35be8d
#@btime scenario(distribution=d,w=Uniform(0.15,0.35),ē=Constant(1.2),q=Shared(1.0),p=80, institution="PLL", target=0.5,color=cm[1])

# ╔═╡ 8b93eab1-525e-4f29-9778-56caeca39777
dd=Normal(1,2)

# ╔═╡ 45bdbcd2-4bb3-4ce3-a24a-55857481659b
Distributions.params(dd)

# ╔═╡ edc7145a-f7ee-4799-9188-fffc58032c69
md"
* min
* max
* median
* mean
* spread (var)
* sum
* distribution
* rand
"

# ╔═╡ e62f61e6-824a-4c8d-909e-6a703a0cb99f
md"
Negative covariance creates weired shit


How q and w covaries matter for policy!!!

make scenarios and check for best outcomes with these differences!!!"

# ╔═╡ 6fabfc3c-6499-4398-a022-6a29c6e06cee
Test=[median(@benchmark sim(scenario(institution=$I,target=0.2,β=0.01))) for I in ["OA","PLL","PHL","EC","TQ","PA"]]

# ╔═╡ de5a9d8a-848a-400c-99b3-4cec8fb7af00
median(@benchmark sim(scenario(institution="TQ", target=0.2)))

# ╔═╡ 2e3cd446-6462-45a9-a140-3e734c9ced65
median(@benchmark sim(scenario(institution="OA")))

# ╔═╡ ded36494-0b6e-43e9-a9f8-47620b5166e5
function individual_u(a,S;labels=true)
	# divide by S.ū
	id=sortperm(S.w̃)
	heatmap!(a,S.t,S.w̃[id],S.t_u[:,id],colormap=cgrad([:white,S.color]))
	!labels ? hidedecorations!(a) : nothing
	hidespines!(a)
end

# ╔═╡ 6ce93c05-a841-4235-a340-a906e2bc4d6a
"""
potential_color=nothing

potential_color==nothing ? potential_color=c : nothing #or ensure its a color?

"""
function phaseplot(A,S; show_required=true,show_potential=true,same_potential_color=true, show_realized=false,show_trajectory=false, regulated_dot_reduction=0.3, attractor_size=30, show_attractor=true,show_target=true, vector_field=false,vector_grid=20)
	
	if !isa(S,Array)
		S=[S]
	end
		
	function get_deriv_vector(y,u,z)
		
		du=zeros(z.N+2)
		usum=cumsum(z.ū)
		Q=findall(usum.<=u)
		n=length(Q)
		deltau=usum[min(z.N,Q[end]+1)]-u
		U=zeros(z.N+2)
		U[Q]=z.ū[Q]
		U[min(z.N,n+1)]=deltau
		U[z.N+1]=y
		dudt(du,U,z,0)
		radian_angle = atan(sum(du[1:z.N]),du[z.N+1])

		radian_angle-pi/2,sqrt(sum(du[1:z.N])^2+du[z.N+1]^2)
	end
	
	for is in S
		p=is
		c=p.color
		MS=10
		id=sortperm(is.w̃)
		if vector_field
			points = [Point2f(x/(vector_grid+1), y/(vector_grid+1)) for y in 1:vector_grid for x in 1:vector_grid]
			rotations = [get_deriv_vector(p[1],p[2],is)[1] for p in points]
			markersizeVector = [(get_deriv_vector(p[1],p[2],is)[2]*20)^0.2*15 for p in points]
	
			scatter!(A,points, rotations = rotations, markersize = markersizeVector*0.7, marker = '|', color=adjustColor(c,"l",0.4))
			scatter!(A,points, rotations = rotations, markersize = 4, color=:black)
	
		end
	
		
		(us,ur,y)=analytical(is)
		if is.institution in ["TQ","EC"] && show_target
	        lines!(A,y,is.target./y, color=c, linewidth=0.5)
		elseif is.institution in ["TQu","ECu", "PLL","PHL"] && show_target
	        lines!(A,y,fill(mean(is.target),length(y)), color=c, linewidth=0.5)
	    end
	
		#Trajectory plot
		show_trajectory ? lines!(A,is.t_y,is.t_U,color=c, linewidth=1,linestyle=:dash) : nothing
		
		institutional_impact=(is.y.-is.w̃ .>0 .&& is.ū.-is.u.>1e-5).*MS*regulated_dot_reduction
		institutional_not_profitable=(is.y.-is.w̃ .<0 ).*MS*1.11
		open_access_not_profitable=(is.y.-is.w̃[id] .<0 ).*MS
		
		optoutvector=[is.w̃[i]>is.y ? is.u[i] : is.u[i] for i in eachindex(is.w̃[id])] #for non-flattened curve: is.final.p.ū[i]
		
		show_potential ? potential=scatter!(A,y,ur,color=same_potential_color ? c : :gray, markersize=MS.*0.3) : nothing

		if show_realized
			inst=MarkerElement(marker = :circle, color = :black,strokecolor = c,strokewidth=1,markersize = MS)

			#Shows actors that opt out of resource use 
			#scatter!(A,is.w̃[id],cumsum(x.u[id]./x.ū[id])/x.N,color=adjustColor(c,"l",0.15), markersize=open_access_not_profitable.*0.3)
			
			realized=scatter!(A,is.w̃[id],cumsum(is.u[id]./is.ū[id])/x.N,color=c, markersize=MS)
			
			#optout=scatter!(A,is.w̃[id],cumsum(optoutvector./is.ū)./is.N,color=adjustColor(c,"l",0.85), markersize=institutional_not_profitable)
			
			#scatter!(A,is.w̃[id],cumsum(is.u./is.ū)./is.N, color=:black,markersize=institutional_impact)
		end
		
		show_trajectory ? scatter!(A,[is.y],[is.U],color=:black,markersize=show_attractor ? 8 : 0,strokecolor=:transparent,strokewidth=0,rotations=pi) : nothing
		scatter!(A,[is.y],[is.U],color=:transparent,markersize=show_attractor ? attractor_size : 0,strokecolor=c,strokewidth=2,rotations=pi)
		
		show_required ? required=lines!(A,y,us,linewidth=1,markersize=1,color=same_potential_color ? c : :gray) : nothing
	end
	ylims!(A,(-0.02,1.02))
	xlims!(A,(0,1))
end

# ╔═╡ b1293a86-441e-4217-a3fd-7188f171383b


# ╔═╡ 4ee8f677-96f1-4b8d-acaa-22272e50db44


# ╔═╡ 42de59c8-4e49-42d5-8b49-e40cbaaf90d7
struct Constant
	v
end

# ╔═╡ 13a85911-4b12-44bd-87f0-ae0876de7258
struct Shared
	v
end

# ╔═╡ fbf28f45-caf9-40ae-89c9-1c7e254b4c04
function constant(v)
	return Constant(v)
end

# ╔═╡ 1e88fb04-d81f-4db8-b59a-b257bd2bc230
function shared(v)
	return Shared(v)
end

# ╔═╡ c38a76c3-08dd-4a2f-a07c-166c6978ae4d
function order(d::Shared,N::Int64)
	return fill(d.v/N,N)
end

# ╔═╡ ae15cf6e-e863-4016-953f-187c37985dfc
function order(d::Distribution,N::Int64)
	return fill(0.111,N)
end

# ╔═╡ d199f2b3-45b7-4447-947c-9f5152aa2a21
function rand(d::Distribution,N::Int64)
	return Distributions.rand(d,N)
end

# ╔═╡ 4c2be6a7-008d-4cfe-b919-5752b28b7ccf
function rand(d::Shared,N::Int64)
	return fill(d.v/N,N)
end

# ╔═╡ 59b4fa2c-8833-4196-8f91-150fb51d6904
function order(d::Constant,N::Int64)
	return fill(d.v,N)
end

# ╔═╡ 22bfcde9-9443-4b94-b0a5-89ea0ec97ac3
function rand(d::Constant,N::Int64)
	return fill(d.v,N)
end

# ╔═╡ 482e9cd9-ec73-490c-8b6e-8fd9262a32a9
function order(d::Uniform,N::Int64)
	mi,ma=Distributions.params(d)
	return range(mi,ma,N)
end

# ╔═╡ 6436faf5-7e2c-421b-851d-2b84bff367c6
begin
	diversity=0.5
	shift=0.25
	corr=1
	cm=colorschemes[:tab10]
	d=order
end

# ╔═╡ 4e8c15ea-3f79-4284-9d0d-c042119e5256
col="forestgreen"

# ╔═╡ ff0602aa-774a-470c-9a0a-206b101efb43
convert(HSL,parse(Colorant, col))

# ╔═╡ 45e101b5-75e1-44b4-928a-28c64089b06c
mutable struct Scenario
		N
		distribution
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
		par_dist
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

# ╔═╡ 45938465-3710-4ce9-9904-27135437b614
function scenario(;
	# basic dimensionalized parameters
	N=100,
	distribution=order,
	ē=Constant(1.0),
	q=Shared(10.0),
	a=Constant(0.1),
	w=Uniform(0.0,1.0),
	r=1.0,
	K=1.0,
	p=1.0,
	
	# basic non-dimensionalized parameters, if set these override dimensionalized parameters
	w̃=nothing,
	ū=nothing,
	α=nothing,

	# institutional parameters
	institution="OA",
	β= institution=="TQ" ? 0.05 : 0.0,
	target=1.0,
	signal="effort",

	#simulation parameters
	ts=0.0, 
	ū0=fill(0.0,N),
	y0=1.0,
	dydt=1.0,
	dt=0.01,
	
	# visualzaion parameters
	label="", 
	image="", 
	caption="", 
	color=nothing,
	simulate=true)
	D=Union{Distribution,Shared,Constant}
	dist=(
	w = isa(w,D) ? w :  nothing,
	q = isa(q,D) ? q :  nothing,
	ē = isa(ē,D) ? ē :  nothing,
	a = isa(a,D) ? a :  nothing,
	p = isa(p,D) ? p :  nothing,
	w̃ = isa(w̃,D) ? w̃ :  nothing,
	ū = isa(ū,D) ? ū :  nothing,
	α = isa(α,D) ? α :  nothing,
	r = isa(r,D) ? r :  nothing,
	K = isa(K,D) ? K :  nothing
	)
	
	w = isa(w,D) ? distribution(w,N) :  w
	q = isa(q,D) ? distribution(q,N) :  q
	ē = isa(ē,D) ? distribution(ē,N) :  ē
	a = isa(a,D) ? distribution(a,N) :  a
	p = isa(p,D) ? distribution(p,N) :  p
	w̃ = isa(w̃,D) ? distribution(w̃,N) :  w̃
	ū = isa(ū,D) ? distribution(ū,N) :  ū
	α = isa(α,D) ? distribution(α,N) :  α
	r = isa(r,D) ? distribution(r,N) :  r
	K = isa(K,D) ? distribution(K,N) :  K
	
   
	#=

	If distribution -> make array and put distribution into dist tuple

	=#

	# if a tuple is provided the distributions get calculated, otherwise they are assumed to be provided as array
	#=
	isa(q,Distribution) ? q=collect(distribution(q,N)) : nothing
	isa(ē,Distribution) ? ē=collect(distribution(ē,N)) : nothing
	isa(a,Distribution) ? a=collect(distribution(a,N)) : nothing
	isa(w,Distribution) ? w=collect(distribution(w,N)) : nothing
	isa(p,Distribution) ? p=collect(distribution(p,N)) : nothing
	isa(K,Distribution) ? K=collect(distribution(K,N)) : nothing
	=#

	# if dimensionalized parameters are set, then non-dimensionalized parameters are calculated from them
	
	w̃==nothing ? w̃=w./(K.*p.*q) : isa(w̃,Distribution) ? w̃=distribution(w̃,N) : nothing
	ū==nothing ? ū=ē.*q./r : isa(ū,Distribution) ? ū=distribution(ū,N) : nothing
	α==nothing ? α=(a.*p.*K.*q)./r : isa(α,Distribution) ? α=distribution(α,N) : nothing
	

	
	#if !(isa(w_mean,Array) || isa(q_sum,Array)) 
		if institution=="PA"
			w̃=w̃./max(0.001,(1-(1-target))) # to avoid dividing by zero
			ū=ū./(1+(1-target))
			q_sum=sum(q)  # this needed?
		end
	#end
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
	distribution,
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
	par_dist=dist,
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
	return S
	
	#Scenario(N,w,q,ē,a,r,K,!isa(p,Array) ? fill(p,N) : p,w̃,ū,ū_sum,α,institution,T,t,target,β,ū0,y0,dt,dydt,label,image,caption,color)

end

# ╔═╡ 3eea0e91-df73-455f-9b02-f5caeba69539
begin

	s1=scenario(distribution=d,w̃=Uniform(0.0,0.5),ū=Shared(1.5),color=cm[4])
	s2=scenario(distribution=d,w̃=Uniform(0.0,0.5),ū=Uniform(.011,.019),color=cm[4])
	s3=scenario(distribution=d,w̃=Uniform(0.5,1.0),ū=Shared(0.5),color=cm[4])
	s4=scenario(distribution=d,w̃=Uniform(0.5,1.0),ū=Shared(0.5),color=cm[4])
	SS=[s1,s2,s3,s4]
end


# ╔═╡ 7c01bfe2-1029-49a9-8bb3-9ba936f89faa
s1

# ╔═╡ c718ce7f-3146-43cc-ae52-b76f8ba6226f
heatmap(s1.t_u,colormap=cgrad([:white,s1.color]))

# ╔═╡ 0f8c499e-1a97-4cbc-aaea-03c4dc05c00b
scatter(s1.t_y,s1.t_U)

# ╔═╡ 42c5b4fb-02af-4c84-934e-6ddc2864d240
s1.t

# ╔═╡ 93da3cf9-5328-41c3-8e06-5739be45929a
	over_exploitation=[
		scenario(distribution=d,w̃=Uniform(0.5-shift-diversity/2,0.5-shift+diversity/2),ū=Shared(1.0+shift*2),color=cm[1]),
		scenario(distribution=d,w̃=Uniform(0.5-shift-diversity/2,0.5-shift+diversity/2),ū=Uniform(0,(1.0+shift*2)*corr),color=cm[2]),
		scenario(distribution=d,w̃=Uniform(0.5-shift-diversity/2,0.5-shift+diversity/2),ū=Shared(1.0+shift*2),color=cm[3]),
		scenario(distribution=d,w̃=Uniform(0.5-shift-diversity/2,0.5-shift+diversity/2),ū=Shared(1.0+shift*2),color=cm[4])]

# ╔═╡ 12b3be06-4a49-4621-b8c6-a5da51f0ad20
S=over_exploitation

# ╔═╡ 29ef46a2-ab37-4cbc-8069-6a66c7f37517
begin
	f=Figure(resolution=(900,900))
	w_cumsum=Axis(f[1,1])
	w̃_cumsum=Axis(f[1,2])
	w_w̃=Axis(f[2,1])
	w̃_ū=Axis(f[2,2])
	heat1=Axis(f[3,1])
	heat2=Axis(f[3,2])
	heat3=Axis(f[4,1])
	heat4=Axis(f[4,2])
	A=Axis(f[3:4,3:4])
	phaseplotAxis=Axis(f[1:2,3:4])
	SEDplot(w_cumsum,S,:w,cumsum)
	SEDplot(w̃_cumsum,S,:w̃,cumsum)
	SEDplot(w_w̃,S,:w,:w̃)
	SEDplot(w̃_ū,S,:w̃,:ū)
	phaseplot(phaseplotAxis,S,show_realized=true, show_trajectory=true)
	individual_u(heat1,s1)
	individual_u(heat2,s2)
	individual_u(heat3,s3)
	individual_u(heat4,s4)
	phaseplot(A,s2,show_trajectory=true,vector_field=false)
	f
end

# ╔═╡ c8212a3e-666f-4458-a8ad-7bb5f6bbcf22
[length(sim(scenario(institution=I,target=0.2,β=0.5)).t) for I in ["OA","PLL","PHL","EC","TQ","PA"]]

# ╔═╡ 1af30e00-7646-48c6-83f6-202dda434793
begin
	SD=sim(scenario(institution="TQ",target=0.2,β=0.02))
	lines(SD.t_y,SD.t_U)
end

# ╔═╡ c08c7edb-b96c-4586-8382-28d2aeb80b9c
scenario(institution="TQ",target=0.2,β=0.1)

# ╔═╡ 8a95c18d-d947-4c51-97e2-f1c3e417bfee
	under_exploitation=[
		scenario(distribution=d,w̃=Uniform(0.5+shift-diversity/2,0.5+shift+diversity/2),ū=Shared(1.5),color=cm[1]),
		scenario(distribution=d,w̃=Uniform(0.5+shift-diversity/2,0.5+shift+diversity/2),ū=Uniform(.011,.019),color=cm[2]),
		scenario(distribution=d,w̃=Uniform(0.5+shift-diversity/2,0.5+shift+diversity/2),ū=Shared(0.5),color=cm[3]),
		scenario(distribution=d,w̃=Uniform(0.5+shift-diversity/2,0.5+shift+diversity/2),ū=Shared(0.5),color=cm[4])]

# ╔═╡ a770907d-b08b-41d0-9a72-19d08f3aaa17
scenario()

# ╔═╡ d64a7729-f969-4d18-bebb-384ad5b8cda1
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
function sim(p; tend=(0.0,2000.0), y0=1.0, dydt=1.0,u0=fill(0.0/p.N,p.N), p0=0.0,solution=false,terminate_steady_state=true)
	t0=time()
    N=p.N
    ū=p.ū
    # sets up the problem,
    prob = ODEProblem(dudt,[u0;y0;p0],tend,p)

    # solves the ODE
    sol=solve(prob,adaptive=false, Euler(),saveat=0.1,callback=terminate_steady_state ? TerminateSteadyState(1e-6,1e-4) : nothing,dt=p.sim.dt)#  
    poa=deepcopy(p)
    poa.institution="OA"
    DUDT=zeros(N+2)
    dudt(DUDT,sol.u[end],poa,0.0)
	individual=zeros(N,length(sol.t))
    [individual[:,i]=sol.u[i][1:end-2] for i in 1:length(sol.t)]
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
	    p.ϕ=sol.u[end][N+2]
		p.t=sol.t
		p.t_u=[sol.u[t][i] for t in 1:length(sol.t), i in 1:p.N]#[u[1:N] for u in sol.u]
	    p.t_y=[u[N+1] for u in sol.u]
	    p.t_ϕ=[u[end] for u in sol.u]
		p.t_U=[sum(u[findall(p.ū.>0.0)]./p.ū[findall(p.ū.>0.0)]./p.N) for u in sol.u]
		
	return p

end

# ╔═╡ ba2ed793-6d81-4a9b-9aae-b7361e5ac180
function dudt(dx,x,p,t)
    # extract the parameters from named tuple containers for simpler equation syntax
    dydt=p.sim.dydt # used when y is held constant
    N=p.N
	ū=p.ū
	w̃=p.w̃
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
	
    if p.institution=="PLL" || p.institution=="PHL" #if permits are used
        n=Int64(round(p.target.*N)) # number of allowed permitholders (can we do this at scenario creation)
        id=findall(u.+dx[1:N].>0.0)      # get all who would like to use resource
        l=length(id)                  # number of potential resource users 
        if l>n  # if number of actors that want to use resource are more than number of permits 
            if p.institution=="PLL" 
                r=l-n+1:l   # select the permit holders (given to high w)
            elseif p.institution=="PHL"
                r=1:n # select the permit holders (given to low w)
            end
            q=1:N
            idq=q[q .∉ Ref(id[r])] #checks if qdy is in id[r] and returns the indices of q that are not in id[r]
            dx[idq]=min.(0.0,-u[idq])
        end
    end
	
#=	
	# PERMITS & PROPERTY RIGHTS
	if p.institution == "PLL" || p.institution == "PHL" #if permits are used
	    n = Int64(round(p.target .* N)) # number of allowed permitholders (can we do this at scenario creation)
	    
	    # Calculate the utility change for potential use
	    utility_change = u .+ dx[1:N]
	    
	    # Get all indices of individuals who would like to use the resource
	    candidates = findall(utility_change .> 0.0)
	    
	    # Number of potential resource users
	    l = length(candidates)
	    
	    if l > n  # If more actors want to use the resource than there are permits
	        if p.institution == "PLL"
	            # For PLL, we give permits to those with the highest utility change
	            # Sort the candidates based on utility change in descending order and take the top `n`
	            permit_holders = sortperm(utility_change[candidates], rev=true)[1:n]
	        elseif p.institution == "PHL"
	            # For PHL, we give permits to those with the lowest utility change
	            # Sort the candidates based on utility change in ascending order and take the top `n`
	            permit_holders = sortperm(utility_change[candidates])[1:n]
	        end
	
	        # Convert the indices back to the original `u` indices
	        permit_holders_indices = candidates[permit_holders]
	
	        # Set the change to zero for those who didn't get a permit
	        non_permit_holders = setdiff(1:N, permit_holders_indices)
	        dx[non_permit_holders] = min.(0.0, -u[non_permit_holders])
	    end
	end
=#
    

    # One can have quota shared equally among all actors or only among those who want to use resource
    if p.institution=="EC"
        # NOTE: WHAT IF NOT ALL QUOTA IS USED? How to assign unused quotas to others
        # If your intention will be higher than your individual quota, then adjust dx to be just at quota.
        dx[1:N].-=ifelse.((u.+dx[1:N]).>p.target/y/p.N, (u.+dx[1:N]).-p.target/y/p.N , 0.0 )
    end
 
    if p.institution=="ECn"
        n=sum((u.+dx[1:N]).>0.0)
        dx[1:N].-=ifelse.((u.+dx[1:N]).>p.target/y/n, (u.+dx[1:N]).-p.target/y/n , 0.0 )
    end

    if p.institution=="ECu"
        dx[1:N].-=ifelse.((u.+dx[1:N]).>p.target/p.N, (u.+dx[1:N]).-p.target/p.N , 0.0 )
    end

    if p.institution=="ECun" 
        n=sum((u.+dx[1:N]).>0.0)
        dx[1:N].-=ifelse.((u.+dx[1:N]).>p.target/n, (u.+dx[1:N]).-p.target/n , 0.0 )
    end
 
    @inline @inbounds dx[1:N].=constrain.(dx[1:N],u,0.0,ū,dt)
    #constrain!.(dx[1:N],u,0.0,ū,dt) Testing an inplace version with potentially less memory allocation

    #TRADABLE QUOTAS
	if p.institution=="TQ"
		supply=max(0.0,p.target-sum(u))
		if true
	        id=findall(dx[1:N].>0.0) # who wants to increase u => id
	
	         # available quotas, but in units of u
	        #demand=sum(max.(0.0,view(ū,id).-(view(u,id).+view(dx,id)))) # demand, as in intending to increase u
	        demand=sum(view(dx,id)) 
			if demand > supply # if demand is greater than supply, buyers have to share supply proportionally to their individual demand or willingness to pay.
	            dx[id].=supply.*view(dx,id)./demand
	        end  
		else
			demand=0
			for i in 1:p.N
				if dx[i]>0.0
					demand=demand+dx[i]
				end
			end
			if demand > supply
				for i in 1:p.N
					dx[i]=supply*dx[i]/demand
				end
			end
		end
        # else they can just do as they please, i.e. dudt is not adjusted

		# Dynamics of tradable quota price
	    @inbounds dx[N+2]= constrain(β*(demand -supply),ϕ,0.0,Inf64,dt) 
	end

    if p.institution=="TQu"
		supply=max(0.0,p.target-sum(u))
		if false
        id=findall(dx[1:N].>0.0) # who wants to increase u => id

         # available quotas, but in units of u
        #demand=sum(max.(0.0,view(ū,id).-(view(u,id).+view(dx,id)))) # demand, as in intending to increase u
        demand=sum(view(dx,id)) 
		else
			demand=0
			for i in 1:p.N
				if dx[i]>0.0
					demand=demand+dx[i]
				end
			end
		end
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

# ╔═╡ fa18c000-fd82-485f-b138-a7243518d61f
html"""
<style>
    body main {
        max-width: calc(100% - 6em) !important;
        margin-left: 1em !important;
        margin-right: 5em !important;
    }
    /* larger images in arrays when expanded */
    pluto-tree img {
        max-width: none !important;
        max-height: none !important;
    }

    /* somewhat larger images in arrays when collapsed */
    pluto-tree.collapsed img {
        max-width: 15rem !important;
        max-height: 15rem !important;
    }
    /* move cell popup menu to the left of its button */
    pluto-input > .open.input_context_menu > ul {
        left: calc(100% - var(--width) - 36px) !important;
    }
    pluto-input > .open.input_context_menu > ul, pluto-input > .open.input_context_menu {
        z-index: 31 !important;
    }

    li.recent > a:after, li.running > a:after {
        display: block;
        content: attr(title);
        font-size: x-small;
    }
	pluto-output code {
		font-family: Geist Mono, monospace;
	}
    li > a[title*="/pluto_notebooks/"] {
        color: rgb(16 113 109);
    }

    ul#recent {
        max-height: none;
    }

</style>
"""

# ╔═╡ d20812fa-c051-4d09-8bd3-7914cb74b94c
# VISUALIZATION COMPONENTS:

begin

	"""
	    SEDplot(a, s, v1, v2; show_density=false, sort=true, markersize=5, labels=true, icons=false, icon_size=30)
	
	Plot a Scatter or Density Enhanced plot for given attributes of a data structure.
	
	# Arguments
	- `a`: the axis or plot object to draw on.
	- `s`: a data structure containing the data and settings for the plot.
	- `v1`: the first variable or attribute to plot. Can be a `Symbol` or `String`.
	- `v2`: the second variable or attribute to plot. Can be a `Symbol` or `String` or special value like `:cumsum` to represent cumulative sum.
	- `show_density`: if `true`, shows a density plot for `v1`; otherwise, shows a scatter plot.
	- `sort`: if `true`, the data points are sorted based on `v1`.
	- `markersize`: size of the markers in the scatter plot.
	- `labels`: if `true`, adds labels to the x and y axes.
	- `icons`: if `true`, adds icons to the plot.
	- `icon_size`: size of the icons if `icons` is `true`.
	
	# Returns
	- The plot object `L` (can be `nothing` if `show_density` is `true`).
	"""
	function SEDplot(a, S, v1, v2; show_density=false, sort=true, markersize=5, labels=true, icons=false, icon_size=30)
	    # Ensure v1 and v2 are Symbols
		v1 = isa(v1, String) ? Symbol(v1) : v1
		v2 = isa(v2, String) ? Symbol(v2) : v2
		S = isa(S,Array) ? S : [S]
		L=[]
	    for s in S
		    # Obtain the color from the data structure
		    plot_color = s.color
		    
		    # Sort indices if needed
		    indices = sort ? sortperm(getfield(s, v1)) : 1:getfield(s, :N)
		    
		    # Initialize the object used for creating legend for this plot
		    L = nothing
		    
		    if show_density
				# !!! USE ACTUAL DISTRIBUTION WHEN AVAILABLE! !!!!
		        # Perform kernel density estimation on the sorted data
		        data_for_kde = getfield(s, v1)[indices]
		        density_estimation = kde(data_for_kde, boundary=extrema(data_for_kde)) 
		        kde_indices = findall(density_estimation.x .> 0)
		        
		        # Plot the density estimation
		        band!(a, density_estimation.x[kde_indices], density_estimation.x[kde_indices] .* 0, density_estimation.density[kde_indices], color=(plot_color, 0.5))
		        lines!(a, density_estimation.x[kde_indices], density_estimation.density[kde_indices], color=plot_color, linewidth=1)
		    else
		        # Scatter plot
		        if v2 == cumsum
		            # Special case for cumulative sum
		            cumulative_data = collect(1:s.N) ./ s.N
		            l = scatter!(a, getfield(s, v1)[indices], cumulative_data, color=plot_color; markersize)
		        else
		            # General case for scatter plot
		            l = scatter!(a, getfield(s, v1), getfield(s, v2), color=plot_color; markersize)
		        end
		    end
		    
		    # Add labels if specified
			 if labels
			    a.xlabel = string(v1)
			    a.ylabel = string(v2)
			end
		
		    
		    # Add icons if specified
		    if icons
		        y_icon = load("graphics/" * string(v2) * ".png")
		        scatter!(a, 0.1, 0.9, marker=y_icon, markersize=icon_size, space=:relative)
		        
		        x_icon = load("graphics/" * string(v1) * ".png")
		        scatter!(a, 0.88, 0.15, marker=x_icon, markersize=icon_size, space=:relative)
		    end
			#push!(L,l) fix for Legend
		end
	    return L
end

	function adjustColor(C,f,v)
		h=C.h
		s=C.s
		l=C.l
		f=="h" ? h=v : nothing
		f=="s" ? s=v : nothing
		f=="l" ? l=v : nothing
		return HSL(h,s,l)
	end

end

# ╔═╡ 475773a2-fb06-4d9f-abfb-8d9cfc713132
# ANALYSIS FUNCTIONS

begin
	function gini(x)
	    sum([abs(x[i]-x[j]) for i in 1:length(x), j in 1:length(x)])/(2*length(x)*sum(x))
	end
	
	function revenues(s; non_dimensional=true)
	    y=s.final.y
	    u=s.final.u
	    ū=s.final.p.ū
	    w̃=s.final.p.w̃
	    
	    T=s.final.p.T
	    N=s.final.p.N
	    ϕ=s.final.ϕ
	    
	    if non_dimensional
	        Ry=y.*u
	        Rw=(ū.-u).*w̃
	        Rq=(T./y./N.-u).*ϕ
	        RT=Ry+Rw+Rq
	        RW=RT.-ū.*w̃
	    else
	        w=s.final.p.w
	        q=s.final.p.q
	        Ry=y.*u.*q
	        Rw=(ū.-u).*w
	        Rq=(T./y./N.-u).*ϕ
	        RT=Ry+Rw+Rq
	        RW=RT.-ū.*w̃
	    end
	    return (;Ry,Rw,Rq,RT,RW
	        )
	end

	function analytical(p)
		Y=range(0.0,stop=max(1.0,maximum(p.w̃))	,length=1000)
	    us=sum.(u_sust.(Y,Ref(p)))/p.N
	    ur=sum.(u_real.(Y,Ref(p)))/p.N
		return (us,ur,Y)
	end
	
	
	function u_sust(y,p)
		id=sortperm(p.w̃)
	    cu=cumsum(p.ū[id])
	    f=sum(cu.<(1.0-y))
	    if f==0
	        f=(1.0-y)/p.ū[id[1]]
	    elseif f<p.N
	        f=f+((1-y)-cu[f])/p.ū[id[f+1]]
	    end
	    return f
	end
	
	function u_real(y,p)
		id=sortperm(p.w̃) # if w_bar's are not in ascending order
	    f=sum(p.w̃[id].<y) # how many are participating
	    return f
	end
	
end


# ╔═╡ 212bb681-6a39-4d7e-b6c8-6185cdacc560
begin
	x=s2
	id=sortperm(x.w̃)
	(us,ur,y)=analytical(x)
	ff,aa=scatter(x.w̃[id],(1:x.N)./x.N, color=:crimson)
	scatter!(aa,x.w̃[id],cumsum((x.u[id]./x.ū[id])./x.N))
	scatter!(aa,y,ur)
	scatter!(aa,y,us)
	scatter!(aa,x.y,x.U)
	ff
end

# ╔═╡ 3dcf5e20-31ad-4865-ac74-50707e655125
x.U

# ╔═╡ c0aa3c00-e2be-4432-8242-8253c451e3f5
scatter(x.t,x.t_y)

# ╔═╡ fd6e36bd-a9e0-435c-b2e8-67ad7dd07169
cumsum((x.u[id]./x.ū[id])./x.N)

# ╔═╡ Cell order:
# ╠═427b27e6-7a74-11ee-37c9-732e5bcb9cc6
# ╠═e7cdb1bc-d09c-477f-81c5-1d5fd73ea939
# ╠═c3ae57f5-ad35-4ab5-8d52-21a2d42e2a17
# ╠═514d39b5-9235-4ef5-8de9-f5b6aa584f4f
# ╠═e4a270e2-16f4-4864-b082-9038ac654501
# ╟─a439ee56-2ec6-4e76-a2af-1f6a58e8bea2
# ╠═6933c920-fcf9-4b15-904b-7df3d97687d3
# ╠═f945534a-5aa3-4b61-8f21-065dac35be8d
# ╠═8b93eab1-525e-4f29-9778-56caeca39777
# ╠═45bdbcd2-4bb3-4ce3-a24a-55857481659b
# ╠═3eea0e91-df73-455f-9b02-f5caeba69539
# ╠═6436faf5-7e2c-421b-851d-2b84bff367c6
# ╠═93da3cf9-5328-41c3-8e06-5739be45929a
# ╠═edc7145a-f7ee-4799-9188-fffc58032c69
# ╠═e62f61e6-824a-4c8d-909e-6a703a0cb99f
# ╠═6fabfc3c-6499-4398-a022-6a29c6e06cee
# ╠═c8212a3e-666f-4458-a8ad-7bb5f6bbcf22
# ╠═1af30e00-7646-48c6-83f6-202dda434793
# ╠═c08c7edb-b96c-4586-8382-28d2aeb80b9c
# ╠═de5a9d8a-848a-400c-99b3-4cec8fb7af00
# ╠═2e3cd446-6462-45a9-a140-3e734c9ced65
# ╠═7c01bfe2-1029-49a9-8bb3-9ba936f89faa
# ╠═12b3be06-4a49-4621-b8c6-a5da51f0ad20
# ╠═8a95c18d-d947-4c51-97e2-f1c3e417bfee
# ╠═212bb681-6a39-4d7e-b6c8-6185cdacc560
# ╠═3dcf5e20-31ad-4865-ac74-50707e655125
# ╠═c0aa3c00-e2be-4432-8242-8253c451e3f5
# ╠═fd6e36bd-a9e0-435c-b2e8-67ad7dd07169
# ╠═29ef46a2-ab37-4cbc-8069-6a66c7f37517
# ╠═c718ce7f-3146-43cc-ae52-b76f8ba6226f
# ╠═0f8c499e-1a97-4cbc-aaea-03c4dc05c00b
# ╠═ded36494-0b6e-43e9-a9f8-47620b5166e5
# ╠═42c5b4fb-02af-4c84-934e-6ddc2864d240
# ╠═6ce93c05-a841-4235-a340-a906e2bc4d6a
# ╠═b1293a86-441e-4217-a3fd-7188f171383b
# ╠═4ee8f677-96f1-4b8d-acaa-22272e50db44
# ╠═42de59c8-4e49-42d5-8b49-e40cbaaf90d7
# ╠═13a85911-4b12-44bd-87f0-ae0876de7258
# ╠═fbf28f45-caf9-40ae-89c9-1c7e254b4c04
# ╠═1e88fb04-d81f-4db8-b59a-b257bd2bc230
# ╠═c38a76c3-08dd-4a2f-a07c-166c6978ae4d
# ╠═ae15cf6e-e863-4016-953f-187c37985dfc
# ╠═d199f2b3-45b7-4447-947c-9f5152aa2a21
# ╠═4c2be6a7-008d-4cfe-b919-5752b28b7ccf
# ╠═59b4fa2c-8833-4196-8f91-150fb51d6904
# ╠═22bfcde9-9443-4b94-b0a5-89ea0ec97ac3
# ╠═482e9cd9-ec73-490c-8b6e-8fd9262a32a9
# ╠═ff0602aa-774a-470c-9a0a-206b101efb43
# ╠═4e8c15ea-3f79-4284-9d0d-c042119e5256
# ╠═45938465-3710-4ce9-9904-27135437b614
# ╠═a770907d-b08b-41d0-9a72-19d08f3aaa17
# ╠═45e101b5-75e1-44b4-928a-28c64089b06c
# ╠═d64a7729-f969-4d18-bebb-384ad5b8cda1
# ╠═ba2ed793-6d81-4a9b-9aae-b7361e5ac180
# ╠═fa18c000-fd82-485f-b138-a7243518d61f
# ╠═d20812fa-c051-4d09-8bd3-7914cb74b94c
# ╠═475773a2-fb06-4d9f-abfb-8d9cfc713132
