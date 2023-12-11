
"""
potential_color=nothing

potential_color==nothing ? potential_color=c : nothing #or ensure its a color?

"""
function phaseplot!(A,S; show_required=true,show_potential=true,same_potential_color=true, show_realized=false,show_trajectory=false, regulated_dot_reduction=0.3, attractor_size=30, show_attractor=true,show_target=true, vector_field=false,vector_grid=20)
	
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
		if is.target=="yield" && show_target
	        lines!(A,y,is.value./y, color=:darkorange, linewidth=0.5)
		elseif is.target=="effort" && show_target
	        lines!(A,y,fill(mean(is.value),length(y)), color=c, linewidth=0.5)
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
	function SEDplot!(a, S, v1, v2; show_density=false, sort=true, markersize=5, labels=true, icons=false, icon_size=30, color=nothing, show_cor=true)
	    # Ensure v1 and v2 are Symbols
		v1 = isa(v1, String) ? Symbol(v1) : v1
		v2 = isa(v2, String) ? Symbol(v2) : v2
		S = isa(S,Array) ? S : [S]
		L=[]
	    for s in S

			# NOTE NOTE NOTE !!!!
			# TO ALLOW PLOTTING AGAINST EXTERNAL VARIABLES:
			# one could have s1 and s2 here and assign s1=s if v1 in internal variables and s1=s.external if v1 in external variables!
			# NOTE NOTE NOTE !!!!

		    # Obtain the color from the data structure
		    plot_color = s.color
		    
		    # Sort indices if needed
		    indices = (sort && v1!=:id) ? sortperm(getfield(s, v1)) : 1:getfield(s, :N)
		    
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
					v=getfield(s, v1)
					id=sortperm(v)
		            l = scatter!(a, v1 != :id ? v.data[id] :  1:length(v), cumulative_data, color= color==nothing ? plot_color : color; markersize)
		        else
		            # General case for scatter plot
		            l = scatter!(a, v1 != :id ? getfield(s, v1) :  1:length(getfield(s, v2)), getfield(s, v2), color= color==nothing ? plot_color : color; markersize)
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

function individual_u!(a,S;labels=true)
	# divide by S.ū
	id=sortperm(S.w̃)
	heatmap!(a,S.t,S.w̃[id],S.t_u[:,id],colormap=cgrad([:white,S.color]))
	!labels ? hidedecorations!(a) : nothing
	hidespines!(a)
end

function incomes!(
    a, z;
    fix_xlim=true,
    indexed=true,
    show_w̃=true,
    show_text=true,
    annotation_size=12,
    densityplot=false,
	wage_indicator=false,
	text_color=:black
    )
    c = z.color
    cw = HSL(c.h, c.s, 0.7)
    mw = (z.w̃[end] - z.w̃[1]) / z.N

    if z.w̃[1] == z.w̃[end]
        mw = z.w̃[end] / 5
    end

    indexed ? nothing : fix_xlim ? xlims!(a, [0, 1]) : xlims!(a, [z.w̃[1], z.w̃[end]])

    hideydecorations!(a)
    hidespines!(a)

    id = sortperm(z.total_revenue)
    if densityplot
        pred = kde(z.total_revenue[id])
        band!(a, pred.x, pred.x .* 0, pred.density, color=(c, 0.5))
        lines!(a, kde(z.total_revenue[id]), color=c)
    else
        barplot!(a, indexed ? collect(1:z.N) : z.w̃, z.total_revenue[id], color=c, width=indexed ? 1 : mw, offset=z.trade_revenue[id])
        barplot!(a, indexed ? collect(1:z.N) : z.w̃, z.wage_revenue[id], color=cw, width=indexed ? 1 : mw, offset=z.trade_revenue[id] + z.resource_revenue[id])
    end

    mi = minimum(z.trade_revenue[id] + z.resource_revenue[id])
    ma = maximum(z.total_revenue[id])
# ylims!(a, (mi - 2 * (ma - mi) / 20, ma)) 

    cmap = cgrad(colorschemes[:rainbow2], z.N, categorical=true)
	if wage_indicator
		for i in 1:z.N
			poly!(a, Rect(i - 0.5, mi - (ma - mi) / 40, 1, -(ma - mi) / 40), color=cmap[i])
		end
	end
	#barplot!(a,collect(1:z.N),z.total_revenue[id],color=c, width=mw)
    if show_text
        text!(a, 0.09, maximum(z.total_revenue) * 0.8, text="Gini: " * string(round(gini(z.total_revenue), digits=2)), font="Arial", align=(:left, :top), color=text_color, fontsize=annotation_size)
        text!(a, 0.09, maximum(z.total_revenue), text="Total: " * string(round(sum(z.total_revenue), digits=2)), font="Arial", align=(:left, :top), color=text_color, fontsize=annotation_size)
        text!(a, 0.09, maximum(z.total_revenue) * 0.9, text="Resource: " * string(round(sum(z.resource_revenue), digits=2)), font="Arial", align=(:left, :top), color=text_color, fontsize=annotation_size)
    end
end


function dependencies(s)

	function midpoint(p1::Point2{Float64}, p2::Point2{Float64})
		println(p1,p2)
		return Point2((p1[1] + p2[1]) / 2, (p1[2] + p2[2]) / 2)
	end
	
	# Function to calculate the angle between two points
	function angle(p1::Point2{Float64}, p2::Point2{Float64})
		return atan(p2[2] - p1[2], p2[1] - p1[1])
	end
	M=Dict()
	I=[:w,:q,:ē,:a,:p,:r,:K]
	E=collect(keys(s.external))
	g=DiGraph()
	for (i,k) in enumerate(vcat(I,E))
		if k in E
			add_vertex!(g)
			M[k]=i
			M[i]=k
		else
			if isa(getfield(s,k),SED)
				if !isempty(getfield(s,k).dependent)
					add_vertex!(g)
					M[k]=i
					M[i]=k
				end 
			end
		end
	end
	for i in I
		if isa(getfield(s,i),SED) 
			N= keys(getfield(s,i).dependent)
			for n in N
				
				add_edge!(g, M[n], M[i])

			end
		end
	end
	
	layout =Spring(C=10.0; iterations=200)#SFDP(Ptype=Float64, tol=0.01, C=0.2, K=0.01)#Spring(; iterations=200)# SFDP(Ptype=Float32, tol=0.01, C=0.2, K=1)#Spring(; iterations=200)#SFDP(Ptype=Float32, tol=0.01, C=0.2, K=1)#Spring(; iterations=200)#Buchheim()#Spring(; iterations=200)#Buchheim()#Spring(; iterations=20)
    pos = layout(g)
	
    f=Figure()
    a=Axis(f[1,1], aspect=1)
    for p in edges(g)
        lines!(a,[pos[p.src][1],pos[p.dst][1]],[pos[p.src][2],pos[p.dst][2]], color=:gray)
        scatter!(a,midpoint(pos[p.src],pos[p.dst]),marker=:utriangle,markersize=10,rotations=angle(pos[p.src],pos[p.dst])-pi/2,color=:gray)
    end

    scatter!(a,pos, markersize=30, strokewidth=5, strokecolor=:white,color=:crimson)

    hidespines!(a)
    hidedecorations!(a)
    f
end