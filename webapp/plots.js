/* Canvas plots keep simulation state and display-only choices separate. */
const SEDPlots = (() => {
    "use strict";
    const models = new Map();
    const color = key => getComputedStyle(document.body).getPropertyValue(`--${key}`).trim();
    const fmt = x => !Number.isFinite(x) ? "—" : Math.abs(x) < 1e-12 ? "0" : Math.abs(x) < 0.01 ? x.toPrecision(2) : Math.abs(x) < 10 ? x.toFixed(2) : x.toFixed(0);
    function setup(canvas) {
        const rect = canvas.getBoundingClientRect(), ratio = Math.min(3, devicePixelRatio || 1);
        const width = Math.max(100, rect.width), height = Math.max(100, rect.height);
        canvas.width = Math.round(width * ratio); canvas.height = Math.round(height * ratio);
        const ctx = canvas.getContext("2d"); ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
        ctx.fillStyle = color("surface"); ctx.fillRect(0, 0, width, height);
        return { ctx, width, height };
    }
    function frame(width, height, xMax = 1, yMax = 1, yMin = 0, transform = x => x) {
        const left = width < 450 ? 48 : 57, right = 16, top = 22, bottom = 44;
        return { x0: left, y0: top, x1: width - right, y1: height - bottom,
            xMax, yMax, yMin,
            x: x => left + x / xMax * (width - right - left),
            y: y => top + (transform(yMax) - transform(y)) / (transform(yMax) - transform(yMin) || 1) * (height - top - bottom) };
    }
    function niceTicks(lo, hi, count = 4) {
        const raw = (hi - lo) / count || 1, exp = 10 ** Math.floor(Math.log10(raw)), f = raw / exp;
        const step = (f <= 1 ? 1 : f <= 2 ? 2 : f <= 2.5 ? 2.5 : f <= 5 ? 5 : 10) * exp;
        const out = [];
        for (let v = Math.ceil(lo / step) * step; v <= hi + step * 0.001; v += step) out.push(v);
        return out;
    }
    function axes(ctx, f, xLabel, yLabel, options = {}) {
        ctx.save(); ctx.font = "10px -apple-system, BlinkMacSystemFont, sans-serif";
        ctx.lineWidth = 0.6; ctx.fillStyle = color("muted"); ctx.textBaseline = "middle";
        const yTicks = options.yTicks || niceTicks(f.yMin, f.yMax);
        for (const v of yTicks) {
            const y = f.y(v);
            ctx.strokeStyle = color("grid"); ctx.beginPath(); ctx.moveTo(f.x0,y); ctx.lineTo(f.x1,y); ctx.stroke();
            ctx.textAlign = "right"; ctx.fillText(options.share ? `${Math.round(100*v)}%` : fmt(v),f.x0 - 8,y);
        }
        const xTicks = options.xTicks || (f.xMax === 1 ? [0,.25,.5,.75,1] : niceTicks(0,f.xMax));
        for (const v of xTicks) {
            const x = f.x(v);
            if (!options.noVerticalGrid) { ctx.strokeStyle = color("grid"); ctx.beginPath(); ctx.moveTo(x,f.y0); ctx.lineTo(x,f.y1); ctx.stroke(); }
            ctx.textAlign = "center"; ctx.fillText(options.actorAxis ? `${Math.round(v*100)}%` : fmt(v), x, f.y1 + 14);
        }
        ctx.strokeStyle = color("axis"); ctx.beginPath(); ctx.moveTo(f.x0,f.y0); ctx.lineTo(f.x0,f.y1); ctx.lineTo(f.x1,f.y1); ctx.stroke();
        ctx.font = "10px -apple-system, BlinkMacSystemFont, sans-serif";
        ctx.textAlign = "center"; ctx.fillText(xLabel,(f.x0+f.x1)/2,f.y1+33);
        ctx.translate(12,(f.y0+f.y1)/2); ctx.rotate(-Math.PI/2); ctx.fillText(yLabel,0,0); ctx.restore();
    }
    function line(ctx, pts, stroke, width = 2, dash = [], alpha = 1) {
        ctx.save(); ctx.strokeStyle = stroke; ctx.lineWidth = width; ctx.setLineDash(dash); ctx.globalAlpha = alpha;
        ctx.lineJoin = "round"; ctx.beginPath(); let pen = false;
        for (const [x,y] of pts) {
            if (!Number.isFinite(x) || !Number.isFinite(y)) { pen = false; continue; }
            if (pen) ctx.lineTo(x,y); else ctx.moveTo(x,y); pen = true;
        }
        ctx.stroke(); ctx.restore();
    }
    function clip(ctx,f) { ctx.save(); ctx.beginPath(); ctx.rect(f.x0,f.y0,f.x1-f.x0,f.y1-f.y0); ctx.clip(); }
    function label(ctx,f,x,y,text,ink,align="left") {
        ctx.save(); ctx.font = "500 11px -apple-system, BlinkMacSystemFont, sans-serif";
        const w = ctx.measureText(text).width;
        x = Math.max(f.x0+4,Math.min(f.x1-w-8,align === "right" ? x-w-8 : x));
        y = Math.max(f.y0+12,Math.min(f.y1-6,y));
        ctx.globalAlpha = .92; ctx.fillStyle = color("surface"); ctx.fillRect(x-3,y-11,w+7,16);
        ctx.globalAlpha = 1; ctx.fillStyle = ink; ctx.fillText(text,x,y); ctx.restore();
    }
    function endpoint(ctx,f,r,ink,text,offset=0) {
        const x=f.x(r.y), y=f.y(r.participation);
        line(ctx,[[x,f.y1],[x,y]],ink,1,[3,4],.5);
        ctx.save(); ctx.fillStyle=ink;ctx.strokeStyle=color("surface");ctx.lineWidth=2;
        ctx.beginPath();ctx.arc(x,y,5.5,0,Math.PI*2);ctx.fill();ctx.stroke();ctx.restore();
        label(ctx,f,x+10,y-12+offset,`${text} y* = ${r.y.toFixed(2)}`,ink,r.y>.72?"right":"left");
    }
    function density(ctx,f,r,p) {
        const n=r.actors.length, bins=36, counts=Array(bins).fill(0), live=Array(bins).fill(0);
        const ordered=r.actors.slice().sort((a,b)=>a.effectiveTheta-b.effectiveTheta);
        for(const a of r.actors) {
            if(a.effectiveTheta<0 || a.effectiveTheta>=1)continue;
            const bin=Math.min(bins-1,Math.floor(a.effectiveTheta*bins));counts[bin]++;live[bin]+=a.fraction;
        }
        ctx.save();
        for(let b=0;b<bins;b++) {
            const x=f.x(b/bins), w=(f.x1-f.x0)/bins-1;
            ctx.fillStyle=color("threshold");ctx.globalAlpha=.13;ctx.fillRect(x,f.y(counts[b]/n*2.1),w,f.y1-f.y(counts[b]/n*2.1));
            ctx.globalAlpha=.3;ctx.fillRect(x,f.y(live[b]/n*2.1),w,f.y1-f.y(live[b]/n*2.1));
        }
        for(let b=0;b<bins;b++) {
            const lo=Math.floor(b*n/bins),hi=Math.floor((b+1)*n/bins);
            const potential=ordered.slice(lo,hi).reduce((s,a)=>s+a.effectivePotential,0);
            const active=ordered.slice(lo,hi).reduce((s,a)=>s+a.effectivePotential*a.fraction,0);
            const y=f.y((b+1)/bins), h=(f.y1-f.y0)/bins-1;
            ctx.fillStyle=color("impact");ctx.globalAlpha=.12;ctx.fillRect(f.x0,y,(f.x1-f.x0)*potential*2.4,h);
            ctx.globalAlpha=.30;ctx.fillRect(f.x0,y,(f.x1-f.x0)*active*2.4,h);
        }
        ctx.restore();
    }
    function balance(canvas,data,p) {
        const {ctx,width,height}=setup(canvas),f=frame(width,height),r=data.policy,show=p.policy!=="none";
        axes(ctx,f,"Resource density, y","Participation (share of all actors)",{share:true});
        clip(ctx,f);
        if(p.densities)density(ctx,f,r,p);
        const drawCurves=(cs,baseline)=> {
            const pts=[];let prev=cs[0].participation;
            cs.forEach(c=> {pts.push([f.x(c.y),f.y(prev)],[f.x(c.y),f.y(c.participation)]);prev=c.participation;});
            line(ctx,pts,baseline?color("baseline"):color("threshold"),baseline?3.1:2.3,[],baseline?.45:1);
            line(ctx,cs.map(c=>[f.x(c.y),f.y(c.required)]),baseline?color("baseline"):color("impact"),baseline?3.1:2.1,[6,4],baseline?.42:1);
        };
        if(show)drawCurves(data.curves.open,true);
        drawCurves(data.curves.policy,false);
        if(p.path) {
            const paths=show?[[data.open,color("baseline"),.3],[r,color("ecology"),.65]]:[[r,color("ecology"),.55]];
            for(const [res,ink,opacity]of paths) {
                const pts=SEDModel.resamplePath(res.path,p.spacing);
                line(ctx,pts.map(a=>[f.x(a.y),f.y(a.participation)]),ink,.7,[],opacity*.4);
                ctx.fillStyle=ink;
                pts.forEach((a,i)=>{ctx.globalAlpha=opacity*(.4+.6*i/pts.length);ctx.beginPath();ctx.arc(f.x(a.y),f.y(a.participation),1.2,0,Math.PI*2);ctx.fill();});
                ctx.globalAlpha=1;
            }
        }
        ctx.restore();
        if(show)endpoint(ctx,f,data.open,color("baseline"),"Open access",22);
        endpoint(ctx,f,r,color("ecology"),show?"Policy":"Attractor");
        const cs=data.curves.policy;
        const a=cs[Math.round(.78*(cs.length-1))],b=cs[Math.round(.72*(cs.length-1))];
        label(ctx,f,f.x(.78),f.y(a.participation)-10,"Participation P(y)",color("threshold"),"right");
        if(Number.isFinite(b.required))label(ctx,f,f.x(.70),f.y(b.required)+21,"Sustainable participation I(y)",color("impact"),"right");
        models.set(canvas,{type:"balance",f,data,p});
    }
    function scatter(canvas,actors,options={}) {
        const {ctx,width,height}=setup(canvas);
        const maxTheta=Math.max(1e-3,...actors.map(a=>a.effectiveTheta??a.theta));
        const maxPotential=Math.max(1e-4,...actors.map(a=>a.effectivePotential??a.potential));
        const f=frame(width,height,maxTheta*1.04,maxPotential*1.12);
        axes(ctx,f,"Exit threshold, θᵢ (units of y)","Impact potential, ūᵢ",{noVerticalGrid:true});
        clip(ctx,f);
        const constrained=options.causal;
        for(const a of actors) {
            ctx.fillStyle=constrained?(a.gender?color("threshold"):color("impact")):(a.fraction>.01?color("threshold"):color("baseline"));
            ctx.globalAlpha=constrained?.58:(a.fraction>.01?.75:.35);
            ctx.beginPath();ctx.arc(f.x(a.effectiveTheta??a.theta),f.y(a.effectivePotential??a.potential),width<450?2:2.7,0,Math.PI*2);ctx.fill();
        }
        ctx.restore();
        if(options.result) {
            const x=f.x(options.result.y);
            line(ctx,[[x,f.y0],[x,f.y1]],color("ecology"),1,[3,4],.7);
            label(ctx,f,x+8,f.y0+16,`y* = ${options.result.y.toFixed(2)}`,color("ecology"));
        }
        if(constrained) {
            label(ctx,f,f.x0+7,f.y0+7,"Orange: constrained access group · blue: comparison group",color("muted"));
        }
        models.set(canvas,{type:"scatter",f,actors});
    }
    function income(canvas,data,p) {
        const {ctx,width,height}=setup(canvas);
        const key={threshold:"effectiveTheta",impact:"potential",use:"physicalUse",group:"group",total:"total"}[p.incomeSort];
        const rows=data.policy.actors.slice().sort((a,b)=>typeof a[key]==="string"?a[key].localeCompare(b[key])||a.total-b.total:a[key]-b[key]||a.total-b.total);
        const openMap=new Map(data.open.actors.map(a=>[a.id,a]));
        const baseline=p.incomeSort==="total"?data.open.actors.slice().sort((a,b)=>a.total-b.total):rows.map(a=>openMap.get(a.id));
        const extrema=rows.flatMap(a=>[a.total,Math.min(0,a.trade),a.resource+a.wages+Math.max(0,a.trade)]).concat(baseline.map(a=>a.total));
        const lo=Math.min(0,...extrema),hi=Math.max(1e-5,...extrema),pad=(hi-lo)*.08;
        const scale=Math.max(1e-9,hi/60),symlog=x=>Math.sign(x)*Math.log1p(Math.abs(x)/scale);
        const f=frame(width,height,1,hi+pad,lo<0?lo-pad:0,p.logIncome?symlog:x=>x);
        const ticks=p.logIncome?niceTicks(0,hi,3).concat(lo<0?niceTicks(lo,0,2):[]):niceTicks(f.yMin,f.yMax);
        axes(ctx,f,`Actors ordered by ${{threshold:"exit threshold",impact:"impact potential",use:"resource use",group:"social group",total:"total income"}[p.incomeSort]}`,p.logIncome?"Income (symmetric log scale)":"Income (non-dimensional)",{actorAxis:true,noVerticalGrid:true,yTicks:ticks});
        const w=(f.x1-f.x0)/rows.length;
        const bar=(i,from,to,ink,opacity=1)=> {
            ctx.globalAlpha=opacity;ctx.fillStyle=ink;
            ctx.fillRect(f.x0+i*w,Math.min(f.y(from),f.y(to)),Math.max(.6,w-.35),Math.abs(f.y(from)-f.y(to)));
        };
        clip(ctx,f);
        rows.forEach((a,i)=> {
            const neg=Math.min(0,a.trade),gross=a.resource+a.wages;
            if(neg<0)bar(i,0,neg,color("transfer"),.85);
            const active=a.fraction>.001;
            const opportunity=Math.min(gross,a.outsideOnly);
            bar(i,neg,neg+(active?opportunity:gross),active?color("opportunity"):color("alternative"),.85);
            if(active && gross>opportunity)bar(i,neg+opportunity,neg+gross,color("rent"),.95);
            if(a.trade>0)bar(i,neg+gross,a.total,color("transfer"),.8);
        });ctx.globalAlpha=1;
        if(p.policy!=="none")line(ctx,baseline.map((a,i)=>[f.x0+(i+.5)*w,f.y(a.total)]),color("baseline"),1.3,[],.8);
        ctx.restore();
        if(lo<0)line(ctx,[[f.x0,f.y(0)],[f.x1,f.y(0)]],color("axis"),.8);
        label(ctx,f,f.x1-4,f.y0+10,`Gini ${data.policy.inequality===null?"undefined":data.policy.inequality.toFixed(2)}`,color("muted"),"right");
        models.set(canvas,{type:"income",f,rows,w,data,p});
    }
    function scan(canvas,data,p,indicators=false) {
        const {ctx,width,height}=setup(canvas),rows=data.scan;
        if(!indicators) {
            const f=frame(width,height);
            axes(ctx,f,"Policy strength (toward stricter regulation)","Actors ordered by exit threshold",{actorAxis:true,share:true});
            const ids=data.base.slice().sort((a,b)=>a.theta-b.theta).map(a=>a.id);
            const cw=(f.x1-f.x0)/rows.length,ch=(f.y1-f.y0)/ids.length;
            rows.forEach((r,j)=>ids.forEach((id,i)=> {
                ctx.globalAlpha=.08+.92*r.result.actors[id].fraction;ctx.fillStyle=color("rent");
                ctx.fillRect(f.x0+j*cw,f.y1-(i+1)*ch,cw+.25,ch+.25);
            }));ctx.globalAlpha=1;
            models.set(canvas,{type:"scan",f,rows});
        }else {
            const specs=[["y","Resource density",color("ecology")],["participation","Participation",color("threshold")],["resource","Resource income",color("impact")],["total","Total income",color("ink")],["inequality","Gini",color("red")],["score","Weighted goal",color("policy")]];
            const scores=SEDModel.scoreRows(rows,p.weights),cols=width>650?3:2,nr=Math.ceil(specs.length/cols);
            specs.forEach(([key,title,ink],i)=> {
                const cellW=width/cols,cellH=height/nr;
                const x0=i%cols*cellW+36,y0=Math.floor(i/cols)*cellH+22,x1=(i%cols+1)*cellW-15,y1=(Math.floor(i/cols)+1)*cellH-20;
                const vals=key==="score"?scores:rows.map(r=>r.result[key]??0),hi=Math.max(...vals,1e-9)*1.06;
                ctx.fillStyle=color("muted");ctx.font="10px -apple-system,sans-serif";ctx.fillText(title,x0,y0-9);
                line(ctx,[[x0,y0],[x0,y1],[x1,y1]],color("axis"),.7);
                ctx.textAlign="right";ctx.fillText(fmt(hi/1.06),x0-4,y0+4);ctx.fillText("0",x0-4,y1);ctx.textAlign="left";
                line(ctx,vals.map((v,j)=>[x0+j/(rows.length-1)*(x1-x0),y1-v/hi*(y1-y0)]),ink,1.8);
            });
            models.set(canvas,{type:"indicators",rows});
        }
    }
    function render(data,p) {
        const phase=document.getElementById("phaseCanvas"),inc=document.getElementById("incomeCanvas");
        if(p.scan&&data.scan) {scan(phase,data,p);scan(inc,data,p,true);}
        else { if(p.view==="actors")scatter(phase,data.policy.actors,{result:data.policy});else balance(phase,data,p); income(inc,data,p); }
    }
    function hit(canvas,x) {
        const m=models.get(canvas);if(!m?.f || x<m.f.x0 || x>m.f.x1)return null;
        const t=(x-m.f.x0)/(m.f.x1-m.f.x0);
        if(m.type==="balance") {
            const c=m.data.curves.policy[Math.round(t*(m.data.curves.policy.length-1))];
            return {title:`Resource density ${c.y.toFixed(2)}`,values:[["Participation",`${(100*c.participation).toFixed(1)}%`],["Sustainable share",Number.isFinite(c.required)?`${(100*c.required).toFixed(1)}%`:"Not attainable"],["Renewal pressure",(1-c.y).toFixed(2)]]};
        }
        if(m.type==="income") {
            const a=m.rows[Math.min(m.rows.length-1,Math.floor(t*m.rows.length))];
            return {title:`Actor ${a.id+1} · ${a.fraction>.001?"harvesting":"outside resource"}`,values:[["Exit threshold",fmt(a.effectiveTheta)],["Impact potential",fmt(a.potential)],["Resource income",fmt(a.resource)],["Outside income",fmt(a.wages)],...(m.p.policy==="rights"?[["Rights transfer",fmt(a.trade)]]:[]),["Total income",fmt(a.total)]]};
        }
        if(m.type==="scan") {
            const r=m.rows[Math.min(m.rows.length-1,Math.floor(t*m.rows.length))];
            return {title:`Policy strength ${r.strength.toFixed(2)}`,values:[["Resource density",fmt(r.result.y)],["Participation",`${(100*r.result.participation).toFixed(0)}%`],["Converged",r.result.converged?"Yes":"Time limit"]]};
        }
        return null;
    }
    return {render,scatter,hit,fmt,color};
})();
