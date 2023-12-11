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

function adjustColor(C,f,v)
    h=C.h
    s=C.s
    l=C.l
    f=="h" ? h=v : nothing
    f=="s" ? s=v : nothing
    f=="l" ? l=v : nothing
    return HSL(h,s,l)
end