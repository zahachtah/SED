/* Static, offline-capable research companion. No account or backend is needed. */
(() => {
    "use strict";
    const $ = id => document.getElementById(id);
    const copy = x => JSON.parse(JSON.stringify(x));
    let p = copy(SEDModel.defaults), draft = copy(SEDModel.causalDefaults);
    const runner = createSEDRunner();
    let data = null, timer = null, lastKey = "", openKey = "", job = 0, toastTimer, tourStep = -1;
    let lastFocus = null;
    const escape = s => String(s).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
    const number = x => Number.isFinite(x) ? (Math.abs(x)>0&&Math.abs(x)<.01?x.toPrecision(2):x.toFixed(2)) : "—";
    const percentKeys = new Set(["exclusion","protected","tourism","royalty","gear","effort","outside"]);
    const displayKeys = new Set(["spacing","view","densities","path","incomeSort","incomeView","logIncome","weights"]);
    const policyNames = {none:"Open access",access:"Exclusive use rights",rights:"Tradable use rights",pa:"Protected area",economic:"Economic instruments"};

    const examples = {
        cluster: { title:"When does a small change matter?", subtitle:"A tight cluster of exit thresholds", values:{meanTheta:.46,thetaSpread:.12,totalImpact:1.35,impactSpread:.5,correlation:0,densities:true},
            body:"Many actors have nearly the same exit threshold. Move the mean threshold a little, then increase heterogeneity. Compare the number who stay in harvesting and the resource outcome." },
        pairing: { title:"Same means. Different futures.", subtitle:"Change who holds the impact potential", values:{meanTheta:.4,thetaSpread:.8,totalImpact:1.55,impactSpread:1.1,correlation:-.85},
            body:"Move threshold–impact pairing from negative to positive. The marginal distributions and their means stay fixed, but the high-impact actors move from low to high exit thresholds. Watch the attractor and the income distribution." },
        tail: { title:"Some actors never enter", subtitle:"Exit thresholds can exceed the resource range",values:{meanTheta:1.1,thetaSpread:.8,totalImpact:1.5,densities:true},
            body:"A threshold is in units of resource density, but it is not restricted to 0–1. Actors with thresholds above one prefer their outside option even at full stock. Participation correctly stays below 100% at y = 1." },
        rights: { title:"Same quota, different beneficiaries", subtitle:"Tradable rights and their allocation",values:{policy:"rights",quota:.5,meanTheta:.4,thetaSpread:.65,totalImpact:1.4,historical:false},
            body:"Keep the quota fixed and switch historical allocation on and off. The market can settle at the same ecological outcome while allocating rents very differently. The dark transfer bars show who receives and who pays." },
        protected: { title:"Protection with a second benefit", subtitle:"Closure, spillover, and tourism",values:{policy:"pa",protected:.3,mobility:.4,tourism:0,meanTheta:.4,totalImpact:1.4},
            body:"Compare no spillover with higher mobility, keeping the protected share fixed. Then open Outside-income benefit and add tourism. Protection changes access; spillover changes the pressure balance; tourism raises feasible outside returns." },
        causes: { title:"Where does dependence come from?",subtitle:"Construct a population from social conditions",values:{populationMode:"causal",view:"actors"},
            body:"This example derives thresholds and impacts from the same actors' health, access constraints, care obligations, and capital. Open the population builder and change how capital affects harvesting efficiency. The resulting dependence can change sign." }
    };

    const equations = {
        none: `<p>Each actor allocates use between harvesting and a feasible outside option. The exit threshold is the resource density at which the actor is indifferent.</p><div class="equation">v<sub>i</sub> = u<sub>i</sub>y + (ū<sub>i</sub> − u<sub>i</sub>)θ<sub>i</sub><br><small>du<sub>i</sub>/dτ = α<sub>i</sub>(y − θ<sub>i</sub>), &nbsp; 0 ≤ u<sub>i</sub> ≤ ū<sub>i</sub><br>dy/dτ = y(1 − y − ∑u<sub>i</sub>)</small></div><p>At equilibrium, actors below the resource density are fully active, actors above it exit, and an actor exactly at the threshold can be partially active. The default response rate is α<sub>i</sub> = 0.05 for every actor.</p>`,
        access: `<p>A use right R<sub>i</sub> is a permitted amount of use, distinct from physical impact potential ū<sub>i</sub>. Sanctions apply to use exceeding that right.</p><div class="equation">v<sub>i</sub> = u<sub>i</sub>y + (ū<sub>i</sub> − u<sub>i</sub>)θ<sub>i</sub><br>− S max(0, u<sub>i</sub> − R<sub>i</sub>)</div><p>This companion shows the paper's <strong>binary, strong-sanction case</strong>: selected actors have R<sub>i</sub> = 0, while others may use their full potential. With S = 1 and nonnegative thresholds, excluded actors cannot gain from harvesting on 0 ≤ y ≤ 1. Numerically their threshold is shifted by one.</p><p>Excluding the same number of high-threshold or low-threshold actors need not remove the same amount of impact. Both curves are calculated from the adjusted population, with all actors retained in the participation denominator.</p>`,
        rights: `<p>The total quota Q is preallocated as use rights R<sub>i</sub>. It can cap <strong>effort</strong> z<sub>i</sub> = u<sub>i</sub> or <strong>catch</strong> z<sub>i</sub> = yu<sub>i</sub>. Users who need additional rights pay; holders of unused rights receive income.</p><div class="equation">v<sub>i</sub> = u<sub>i</sub>y + (ū<sub>i</sub> − u<sub>i</sub>)θ<sub>i</sub><br>+ (R<sub>i</sub> − z<sub>i</sub>)φ<br><small>∑R<sub>i</sub> = Q, &nbsp; dφ/dτ = 0.05(∑z<sub>i</sub> − Q), &nbsp; φ ≥ 0</small></div><p>For effort rights the price adds φ to exit thresholds. For catch rights the marginal return is y(1 − φ) − θ<sub>i</sub>. The market price is an integrated state variable, not a fitted shift or a precomputed equilibrium price.</p><h3>Who initially owns the rights?</h3><p>Equal allocation gives Q/N to every actor. Historical allocation gives Q/n<sup>OA</sup> equally to actors with positive open-access use, and zero to others. History determines eligibility, not the size of each recipient's allocation.</p><p>At a binding equilibrium, total rights use equals Q and transfers sum to zero. Open the convergence details to inspect both residuals. The maximum displayed quota is the unregulated boundary, so the equations reduce to open access there.</p>`,
        pa: `<p>A protected share f reduces access to harvesting. Mobility m allows resource spillover from the protected area into the exploited area. A tourism benefit can additionally raise outside returns.</p><div class="equation">θ<sub>i</sub><sup>PA</sup> = (1 + t)θ<sub>i</sub> / (1 − f)<br><small>y<sub>p</sub> = [(1 − m) + √((1 − m)² + 4my)] / 2<br>h(y) = [f/(1 − f)] m(y<sub>p</sub> − y)/y<br>κ(y) = (1 − y) / [1 − y + h(y)]<br>ū<sub>i</sub><sup>PA</sup>(y) = κ(y)ū<sub>i</sub></small></div><p>The one-resource model uses ecological-equivalent use, scaled by κ, to reproduce the equilibrium balance of the protected/exploited-patch model. <strong>Income uses physical effort and the original effort endowment.</strong> The ecological scaling does not destroy an actor's time or gear.</p><p>At f = 0 the policy becomes open access. This is the tested quasi-steady spatial reduction; the explicit two-patch transient model remains in the Julia package.</p>`,
        economic: `<p>Dimensional mechanisms must be transformed together. A royalty ρ reduces retained price; gear support changes harvesting efficiency q; time or seasonal constraints change feasible effort; outside opportunities also include outside constraints.</p><div class="equation">θ<sub>i</sub><sup>*</sup> = θ<sub>i</sub> (1 + w) / [(1 − ρ)(1 + g)]<br>ū<sub>i</sub><sup>*</sup> = ū<sub>i</sub> (1 + g)(1 + e)</div><p>Here g is the proportional change in efficiency, e the change in effort endowment, and w the change in feasible outside returns. A literal efficiency increase <strong>lowers thresholds and raises impact potential simultaneously</strong>. An effort change isolates the impact channel.</p><p>Income is reported in the original common numeraire pKr. Retained harvest revenue is (1 − ρ)u<sub>i</sub>y; resource rent subtracts forgone outside earnings, u<sub>i</sub>θ<sub>i</sub>(1 + w)/(1 + g). Actual outside earnings use the remaining effort and that same outside-return coefficient. Royalty proceeds leave actor income and are not silently redistributed. The behavioral response rate is held at the selected α<sub>i</sub>.</p>`
    };

    const tours = [
        ["populationSection","Meet the actors","An exit threshold is the resource level below which harvesting loses to an actor's outside option. Impact potential is the pressure that actor could exert at full use. The orange and blue controls change these separate dimensions.","Change the mean exit threshold and watch the participation curve move."],
        ["populationSection","The pairing matters","The two marginal distributions are not the whole population. Pairing determines whether high-impact actors have low thresholds and remain active in a depleted resource, or high thresholds and exit sooner.","Move the pairing control between negative and positive values, then switch the plot to Actors."],
        ["phaseCanvas","Find the balance","Orange counts willing actors. Dashed blue asks how many actors, ordered by threshold, would supply the pressure that balances renewal. Their crossing predicts the attractor; the point is the numerical simulation endpoint.","Hover over the balance plot to compare the two shares at any resource density."],
        ["policySection","Introduce a policy","Each intervention is simulated from the same population's open-access attractor. Grey curves retain the baseline. The outcome strip reports policy values, with signed changes relative to open access.","Choose tradable use rights and change the quota, then change who initially holds the rights."],
        ["incomeCanvas","Follow the income","Darker bars show resource rent: retained harvest revenue minus forgone outside earnings. Lighter bars show that opportunity cost; grey shows actual outside earnings, including for partially active actors. Rights transfers are separate payments or receipts.","Order by exit threshold to connect activity with actor position, or by total income to read inequality."],
        ["causalButton","Build the distributions from social conditions","The joint threshold–impact distribution can be derived rather than imposed. Health, gendered access, care responsibilities, and capital affect w, q, and feasible effort for the same actors.","Open the population builder. Change one pathway, inspect the joint distribution, then use that population in the simulation."]
    ];

    function icons() { window.lucide?.createIcons(); }
    function status(text, state="ready") { $("runStatus").textContent=text;$("statusButton").dataset.state=state; }
    function toast(text) {$("toast").textContent=text;$("toast").hidden=false;clearTimeout(toastTimer);toastTimer=setTimeout(()=>$("toast").hidden=true,3500);}
    const populationKey = SEDModel.populationKey;
    function physicsKey(q) {return JSON.stringify(Object.fromEntries(Object.entries(q).filter(([key])=>!displayKeys.has(key))));}
    function controls() {
        for(const node of document.querySelectorAll("[data-param]")) {
            const key=node.dataset.param;
            if(node.type==="checkbox")node.checked=!!p[key];else node.value=p[key];
            if(node.type==="range") {
                const value=+node.value,min=+node.min,max=+node.max;
                node.style.setProperty("--progress",`${100*(value-min)/(max-min)}%`);
                const out=document.querySelector(`output[for="${node.id}"]`);
                if(out)out.textContent=percentKeys.has(key)?`${value>0&&["tourism","gear","effort","outside"].includes(key)?"+":""}${Math.round(value*100)}%`:["n","seed","scanPoints"].includes(key)?value:key==="spacing"?value.toFixed(3):value.toFixed(2);
            }
        }
        document.querySelectorAll("[data-sampling]").forEach(b=>b.setAttribute("aria-pressed",String(p[b.dataset.sampling]===b.dataset.value)));
        document.querySelectorAll("[data-view]").forEach(b=>b.setAttribute("aria-pressed",String(p.view===b.dataset.view)));
        document.querySelectorAll("[data-income-view]").forEach(b=>b.setAttribute("aria-pressed",String(p.incomeView===b.dataset.incomeView)));
        document.querySelectorAll("[data-policy]").forEach(n=>n.hidden=n.dataset.policy!==p.policy);
        document.querySelectorAll("[data-economic]").forEach(n=>n.hidden=p.economicMode!=="combined"&&n.dataset.economic!==p.economicMode);
        $("policyMode").hidden=p.policy==="none";$("scanOptions").hidden=!p.scan;
        document.querySelector(".workspace").classList.toggle("is-scanning",p.scan);
        $("instrumentButton").setAttribute("aria-pressed",String(!p.scan));$("scanButton").setAttribute("aria-pressed",String(p.scan));
        document.querySelectorAll(".scan-bound").forEach(n=>n.hidden=p.scan);
        $("quota").max=p.target==="yield"?.5:1;
        $("directControls").hidden=p.populationMode!=="direct";$("derivedPopulation").hidden=p.populationMode==="direct";
        $("populationModeLabel").textContent=p.populationMode==="direct"?"Different actors. A shared resource.":p.populationMode==="causal"?"Derived from social conditions":"Imported actor records";
        const summary={none:"Actors choose between harvesting and their outside option.",access:"Who loses access matters as much as how many.",rights:"The quota creates a price. Initial rights decide who receives the rents.",pa:"Protection changes access and the resource balance.",economic:"A change in efficiency affects both thresholds and impacts."};
        $("policySummary").textContent=summary[p.policy];
        $("populationCount").textContent=`${p.populationMode==="imported"?p.records.length:p.n} actors · ${p.populationMode==="direct"?(p.thresholdSampling===p.impactSampling?p.thresholdSampling:"mixed"):p.populationMode}`;
        $("baselineKey").hidden=p.policy==="none"||p.scan;
        $("tradeKey").hidden=p.policy!=="rights"||p.scan;
        $("incomeKey").hidden=p.scan||p.incomeView==="change";
        $("incomeChangeKey").hidden=p.scan||p.incomeView!=="change";
        document.querySelector(".income-tools").hidden=p.scan;
        document.querySelector(".check-tools").hidden=p.scan;
        document.querySelector(".phase-section .view-switch").hidden=p.scan;
    }

    function render() {
        controls(); if(!data)return;
        const scan=p.scan&&data.scan;
        const incomeChange=p.incomeView==="change";
        $("phaseTitle").textContent=scan?"Who stays as policy changes?":p.view==="actors"?"The actors behind the curves":"Where does the resource settle?";
        $("incomeTitle").textContent=scan?"How do the outcomes compare?":incomeChange?"Who gains, and who loses?":"Who harvests, and who gains?";
        $("incomeFootnote").textContent=scan?"Every scan point starts from the same open-access attractor. Goals use the stored outcomes.":incomeChange?(p.policy==="none"?"Open access is the reference: every actor's income change is zero.":"Each bar is the same actor's total income minus their open-access income."):"Resource rent is retained harvest revenue minus opportunity cost. Grey bars are actual outside earnings."+(p.policy!=="none"?" The grey line is open access.":"");
        $("incomeCanvas").setAttribute("aria-label",scan?"Outcomes across policy strength":incomeChange?"Actor income changes relative to open access":"Actor incomes at the attractor");
        document.querySelector('[data-canvas="incomeCanvas"]').setAttribute("aria-label",scan?"Download the policy outcomes figure":incomeChange?"Download the income change figure":"Download the income distribution figure");
        $("phaseCanvas").setAttribute("aria-label",scan?"Participation across policy strength":p.view==="actors"?"Individual actors by exit threshold and impact potential":"Participation and sustainable participation by resource density");
        const r=data.policy;
        const takeaway=scan?`${data.scan.filter(x=>x.result.converged).length} of ${data.scan.length} scan points met the convergence criterion.`:p.view==="actors"?"Each point is an actor. Its position preserves the pairing of exit threshold and impact potential.":`At ${r.converged?"equilibrium":"the current endpoint"}, resource density is ${r.y.toFixed(2)} and ${(r.participation*100).toFixed(0)}% of full-use actor equivalents participate.`;
        $("phaseTakeaway").lastElementChild.textContent=r.boundary&&!scan?"The trajectory approaches a depleted-resource boundary; an interior curve crossing does not describe this case.":takeaway+(!scan&&p.view==="balance"&&p.densities?" Bars: threshold shares (orange), impact mass by ordered actor rank (blue).":"");
        $("outcomesHeading").textContent=scan?"Policy scan":p.policy==="none"?"At the attractor":"Policy outcome · change from open access";
        $("comparisonLabel").textContent=scan?"At the weighted-goal maximum":"Non-dimensional units";
        const metrics=[["Resource density","y"],["Participation","participation"],["Total pressure","pressure"],["Resource rent","resourceRent"],["Total income","total"],["Income Gini","inequality"],["Policy impact","policyImpact"]];
        const best=scan?data.scan[SEDModel.scoreRows(data.scan,p.weights).indexOf(1)].result:r;
        $("metrics").innerHTML=metrics.map(([title,key])=> {
            const v=best[key],open=data.open[key],diff=(v??0)-(open??0),isShare=key==="participation";
            const value=v===null?"—":isShare?`${Math.round(v*100)}%`:number(v);
            const delta=p.policy!=="none"?`<span class="metric-delta ${diff>1e-6?"positive":diff< -1e-6?"negative":"zero"}">(${diff>=0?"+":""}${isShare?`${Math.round(100*diff)}pp`:number(diff)})</span>`:"";
            return `<div class="metric" title="${escape(title)}${key==="participation"?": full-use equivalents as a share of all actors":key==="policyImpact"?": sum of absolute use changes relative to open access":key==="resourceRent"?": retained harvest revenue minus forgone outside earnings, before rights transfers":""}"><div class="metric-label">${title}</div><div class="metric-value">${value}${delta}</div></div>`;
        }).join("");
        const mTheta=SEDModel.moments(r.actors.map(a=>a.effectiveTheta)),mImpact=SEDModel.moments(r.actors.map(a=>a.effectivePotential));
        $("distributionStats").innerHTML=`<span class="threshold-text">Threshold mean / median / variance &nbsp; ${number(mTheta.mean)} / ${number(mTheta.median)} / ${number(mTheta.variance)}</span><span class="impact-text">Impact mean / median / variance &nbsp; ${number(mImpact.mean)} / ${number(mImpact.median)} / ${number(mImpact.variance)}</span>`;
        $("marketSummary").hidden=p.policy!=="rights"&&!(p.policy==="economic"&&p.royalty>0);
        $("marketSummary").textContent=p.policy==="rights"?`Rights price φ = ${number(r.price)} · Quota used ${number(r.quotaUse)} / ${number(p.quota)}`:`State receipts ${number(r.stateRevenue)} · Not redistributed to actors`;
        SEDPlots.render(data,p);
        window.__lastModelResult=data;
    }

    function simulate() {
        controls();const key=physicsKey(p);
        clearTimeout(timer);const id=++job;runner.cancel();
        const completed=result=> {
            const complete=result.open.converged&&result.policy.converged&&(!result.scan||result.scan.every(r=>r.result.converged));
            status(complete?(result.policy.boundary?"Resource depleted":"Equilibrium reached"):"Convergence details",complete?"ready":"warning");render();
        };
        if(data&&key===lastKey) {completed(data);return;}
        status("Updating simulation","running");
        timer=setTimeout(async()=> {
            const current=copy(p),pk=populationKey(current);
            const cached=data&&pk===openKey?data.open:null;
            try {
                const result=await runner.run(current,cached,s=> {
                    if(id!==job)return;
                    status(s.stage==="fallback"?"Running on main thread":s.stage==="scan"?`Scanning ${s.completed} / ${s.total}`:s.stage==="open"?"Finding open access":"Applying policy","running");
                });
                if(!result||id!==job)return;
                data=result;lastKey=key;openKey=pk;completed(result);
            }catch(error) {if(id===job){status("Simulation needs attention","error");toast(error.message);}}
        },50);
    }

    function change(key,value) {
        p[key]=value;
        if(key==="policy")p.scan=false;
        if(key==="target")p.quota=Math.min(p.quota,p.target==="yield"?.5:1);
        if(key==="economicMode"&&value!=="combined") {
            for(const k of ["royalty","gear","effort","outside"])p[k]=0;
            p[value]=value==="royalty"?.2:.3;
        }
        if(displayKeys.has(key)){controls();if(data)render();}else simulate();
    }

    function dialog(title,body,eyebrow="Inside the model") {
        lastFocus=document.activeElement;$("dialogTitle").textContent=title;$("dialogEyebrow").textContent=eyebrow;
        $("dialogBody").innerHTML=body;$("tourFooter").hidden=true;
        if(!$("infoDialog").open)$("infoDialog").showModal();icons();
    }
    function closeDialog() {$("infoDialog").close();document.querySelectorAll(".tour-focus").forEach(n=>n.classList.remove("tour-focus"));lastFocus?.focus();}
    function loadExample(name) {
        const ex=examples[name];p={...copy(SEDModel.defaults),...ex.values};
        if(p.populationMode==="causal")p.causal=copy(SEDModel.causalDefaults);
        $("examplesMenu").hidden=true;$("examplesButton").setAttribute("aria-expanded","false");simulate();
        dialog(ex.title,`<p>${ex.body}</p><p class="fine-print">Illustrative scenario. Each change runs a new numerical simulation to its convergence criterion.</p>`,"Explore a question");
    }
    function showTour(step) {
        tourStep=step;document.querySelectorAll(".tour-focus").forEach(n=>n.classList.remove("tour-focus"));
        const [id,title,body,tryThis]=tours[step];$(id).classList.add("tour-focus");
        dialog(title,`<p>${body}</p><p><strong>Explore:</strong> ${tryThis}</p>`,`A short tour / ${step+1} of ${tours.length}`);
        $("tourFooter").hidden=false;$("tourFooter").innerHTML=`<button class="text-button" id="previousTour" ${step===0?"disabled":""}><i data-lucide="arrow-left"></i>Previous</button><button class="primary-button" id="nextTour">${step===tours.length-1?"Start exploring":"Next"}<i data-lucide="arrow-right"></i></button>`;
        $("previousTour").onclick=()=>showTour(step-1);$("nextTour").onclick=()=>step===tours.length-1?closeDialog():showTour(step+1);icons();
    }

    function diagnostics() {
        if(!data)return;
        const rows=[...[['Open access',data.open]],...(p.policy!=="none"?[[policyNames[p.policy],data.policy]]:[])];
        dialog("Numerical convergence",`<p>Every point and income component comes from the numerical endpoint. Equilibrium requires the projected state derivatives and the replacement-pressure balance error to be below 8 × 10<sup>−8</sup>, after a minimum ecological time of 35.</p><table><tr><th>Run</th><th>Resource</th><th>Time</th><th>Residual</th></tr>${rows.map(([name,r])=>`<tr><td>${name}${r.converged?"":" · time limit"}</td><td>${r.y.toFixed(5)}</td><td>${r.time.toFixed(1)}</td><td>${r.residual.toExponential(2)}</td></tr>`).join("")}</table>${p.policy==="rights"?`<p>Quota residual: ${data.policy.quotaResidual.toExponential(2)}.<br>Transfer balance: ${data.policy.transferBalance.toExponential(2)}.<br>Price: ${data.policy.price.toFixed(5)}.</p>`:""}${data.scan?`<p>Scan convergence: ${data.scan.filter(r=>r.result.converged).length} of ${data.scan.length} points.${data.scan.some(r=>!r.result.converged)?" Time-limited points: "+data.scan.filter(r=>!r.result.converged).map(r=>r.strength.toFixed(2)).join(", "):""}</p>`:""}<p>Policy runs start from the same realized population's open-access attractor. The adaptive solver projects use, resource density, and the permit price onto their feasible domains. Plot spacing changes the displayed samples, not the simulated trajectory.</p>`);
    }

    function methods() {
        dialog("A distributional view of the commons",`<p>Actors differ in the resource density at which they leave harvesting and in the impact they can exert. Their joint distribution connects individual conditions to resource outcomes and inequality.</p>${equations.none}<h3>Reading the two population curves</h3><div class="equation">P<sub>−</sub>(y) = N<sup>−1</sup> ∑ 1(θ<sub>i</sub> &lt; y)<br><small>I(y) = [k + (1 − y − C<sub>k</sub>)/ū<sub>(k+1)</sub>]/N<br>C<sub>k</sub> = ∑<sub>j≤k</sub> ū<sub>(j)</sub>, actors ordered by θ</small></div><p>I(y) expresses required pressure in full-use actor equivalents, including interpolation within the marginal actor. If the eligible population cannot supply 1 − y, I(y) is undefined and the curve is omitted there. No artificial plateau is added. At an exact threshold P contains a vertical interval; marginal use can select a point on it.</p><h3>Sampling and dependence</h3><p>Direct controls use lognormal marginals. Ordered quantiles preserve deterministic marginal ranks, paired using a low-discrepancy Gaussian copula. Random sampling draws from the same Gaussian dependence model. The pairing control is latent Gaussian correlation, not the Pearson correlation of the transformed lognormal values. Thresholds may exceed one; the cumulative curve is never renormalized to the plotting window.</p><h3>Horizontal impact bars</h3><p>The blue bars are <strong>impact mass by threshold-ordered population rank</strong>, not a density of impact values on the participation axis. Their widths scale with summed impact potential; the darker portion is realized active use. The orange bars are threshold-bin shares of all actors, with darker portions active at the endpoint.</p><h3>Scope and sources</h3><p>The companion implements open access, binary exclusive rights, dynamic tradable effort/catch rights, the protected-area equilibrium reduction, and explicit dimensional economic changes. It uses the Julia package's equations and is tested against fixed-population Julia reference runs. It does not implement the experimental development or full two-patch transient model.</p><p>Manuscript (pending approval) &nbsp; · &nbsp; Supplementary material (pending approval)</p><p><a href="https://github.com/zahachtah/SED" target="_blank" rel="noopener">Julia source &amp; reproducibility</a></p>`);
    }

    function causalControls() {
        const labels={health:"Health",gender:"Gendered access",care:"Parental / care duties",capital:"Capital & networks"};
        $("pathwayTable").innerHTML=`<span></span><span class="column-title">Outside w</span><span class="column-title">Efficiency q</span><span class="column-title">Effort ē</span>`+Object.entries(labels).map(([key,label])=>`<span>${label}</span>`+draft.coefficients[key].map((v,k)=>`<input type="number" min="-2" max="2" step="0.05" value="${v}" data-cause="${key}" data-column="${k}" aria-label="${escape(label)} effect on ${["outside returns","efficiency","available effort"][k]}">`).join("")).join("");
        const constants={w:"Baseline outside return",q:"Baseline efficiency",e:"Baseline effort endowment",p:"Resource price p",K:"Carrying capacity K",r:"Renewal rate r",noise:"Residual log spread"};
        $("causalConstants").innerHTML=Object.entries(constants).map(([k,label])=>`<label>${label}<input data-constant="${k}" type="number" value="${draft[k]}" min="${k==="noise"?0:.00001}" max="${k==="noise"?2.5:100}" step="${k==="e"?.0001:.05}"></label>`).join("");
        $("pathwayTable").oninput=e=>{if(e.target.dataset.cause){const v=Number(e.target.value);if(Number.isFinite(v)&&Math.abs(v)<=2){draft.coefficients[e.target.dataset.cause][+e.target.dataset.column]=v;previewCausal();}}};
        $("causalConstants").oninput=e=>{const key=e.target.dataset.constant,v=Number(e.target.value);if(key&&Number.isFinite(v)&&v>=(key==="noise"?0:.00001)&&v<=(key==="noise"?2.5:100)){draft[key]=v;previewCausal();}};
    }
    function previewCausal() {
        const a=SEDModel.causalPopulation(p,draft),theta=a.map(a=>a.theta),impact=a.map(a=>a.potential);
        $("causalCorrelation").textContent=`corr(θ, ū) = ${SEDModel.correlation(theta,impact).toFixed(2)}`;
        $("causalMoments").innerHTML=`<span>Mean threshold <b>${number(SEDModel.moments(theta).mean)}</b></span><span>Total impact potential <b>${number(impact.reduce((s,v)=>s+v,0))}</b></span>`;
        SEDPlots.scatter($("causalCanvas"),a,{causal:true});
    }
    function openCausal() {lastFocus=document.activeElement;draft=copy(p.causal||SEDModel.causalDefaults);causalControls();$("drawerShade").hidden=false;$("causalDrawer").hidden=false;document.querySelector(".app-layout").inert=true;document.querySelector(".masthead").inert=true;$("closeCausal").focus();previewCausal();}
    function closeCausal() {$("drawerShade").hidden=true;$("causalDrawer").hidden=true;document.querySelector(".app-layout").inert=false;document.querySelector(".masthead").inert=false;lastFocus?.focus();}

    function download(name,content,type) {
        const url=URL.createObjectURL(new Blob([content],{type})),a=document.createElement("a");a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
    }
    function exportScenario() {download("SED_scenario.json",JSON.stringify({format:"SED-companion",version:1,parameters:p,realizedPopulation:data?.base,provenance:{engine:"SED browser companion 2.0",source:"https://github.com/zahachtah/SED",model:"Projected actor dynamics with adaptive RK23"}},null,2),"application/json");}
    function exportActors() {
        if(!data)return;
        const keys=["id","theta","potential","cost","effectiveTheta","effectivePotential","use","physicalUse","fraction","right","resource","wages","trade","total","group","w","q","e","health","gender","care","capital"];
        const csv=v=>`"${String(v??"").replace(/"/g,'""')}"`;
        download("SED_actor_outcomes.csv",keys.join(",")+"\n"+data.policy.actors.map(a=>keys.map(k=>csv(a[k])).join(",")).join("\n"),"text/csv");
    }
    function validate(input) {
        if(!input||typeof input!=="object")throw Error("A scenario must be a JSON object.");
        const merged={...copy(SEDModel.defaults)};
        for(const [key,value]of Object.entries(input)) {
            if(!(key in merged)&&!["causal","records"].includes(key))continue;
            if(typeof merged[key]==="number"&&(!Number.isFinite(value)||Math.abs(value)>10000))throw Error(`Invalid ${key}.`);
            merged[key]=value;
        }
        merged.n=Math.round(Math.max(24,Math.min(1000,merged.n)));
        for(const node of document.querySelectorAll("input[data-param][type=range]")) {
            const key=node.dataset.param;merged[key]=Math.max(+node.min,Math.min(+node.max,merged[key]));
        }
        for(const node of document.querySelectorAll("select[data-param]"))if(![...node.options].some(o=>o.value===merged[node.dataset.param]))throw Error(`Unknown ${node.dataset.param}.`);
        for(const key of ["thresholdSampling","impactSampling"])if(!["ordered","random"].includes(merged[key]))throw Error("Unknown sampling mode.");
        if(!["levels","change"].includes(merged.incomeView))throw Error("Unknown income view.");
        if(!["direct","causal","imported"].includes(merged.populationMode))throw Error("Unknown population mode.");
        if(merged.causal) {
            const c=merged.causal;
            for(const k of Object.keys(SEDModel.causalDefaults).filter(k=>k!=="coefficients"))if(!Number.isFinite(c[k])||c[k]<(k==="noise"?0:.00001)||c[k]>(k==="noise"?2.5:100))throw Error(`Invalid dimensional parameter ${k}.`);
            for(const k of Object.keys(SEDModel.causalDefaults.coefficients))if(!Array.isArray(c.coefficients?.[k])||c.coefficients[k].length!==3||c.coefficients[k].some(v=>!Number.isFinite(v)||Math.abs(v)>2))throw Error("Invalid pathway coefficients.");
        }
        if(merged.records) {
            if(!Array.isArray(merged.records)||merged.records.length<2||merged.records.length>1000)throw Error("Use 2–1000 actor records.");
            merged.records=merged.records.map((a,id)=>{if(!Number.isFinite(a.theta)||a.theta<0||!Number.isFinite(a.potential)||a.potential<=0)throw Error("Actor records need a nonnegative theta and a positive potential.");return {...a,id};});
            merged.n=merged.records.length;
        }
        if(merged.populationMode==="imported"&&!merged.records)throw Error("The imported population has no actor records.");
        merged.weights=Object.fromEntries(Object.keys(SEDModel.defaults.weights).map(key=>[key,merged.weights?.[key]??SEDModel.defaults.weights[key]]));
        if(Object.values(merged.weights).some(v=>!Number.isFinite(v)||Math.abs(v)>2))throw Error("Invalid goal weights.");
        if(merged.policy==="none")merged.scan=false;
        return merged;
    }
    function share() {
        const hash=encodeURIComponent(JSON.stringify(p));
        const url=new URL(location.href);url.hash=`scenario=${hash}`;
        history.replaceState(null,"",url);
        if(navigator.clipboard?.writeText)navigator.clipboard.writeText(url.href).then(()=>toast("Scenario link copied")).catch(()=>dialog("Share this scenario",`<p>The current URL now contains the scenario settings. Copy it from the address bar, or export a scenario file.</p>`));
        else dialog("Share this scenario",`<p>The current URL now contains the scenario settings. Copy it from the address bar, or export a scenario file. A file URL is usable on this computer; an online-hosted copy can be shared with collaborators.</p>`);
    }

    function theme(value) {document.body.dataset.theme=value;$("themeButton").innerHTML=`<i data-lucide="${value==="dark"?"sun":"moon"}"></i>`;$("themeButton").setAttribute("aria-label",`Switch to ${value==="dark"?"light":"dark"} mode`);try{localStorage.setItem("sed-companion-theme",value);}catch{}icons();if(data)render();if(!$("causalDrawer").hidden)previewCausal();}

    document.querySelectorAll("[data-param]").forEach(node=>node.addEventListener("input",()=>change(node.dataset.param,node.type==="checkbox"?node.checked:node.tagName==="SELECT"?node.value:Number(node.value))));
    document.querySelectorAll("[data-sampling]").forEach(node=>node.onclick=()=>change(node.dataset.sampling,node.dataset.value));
    document.querySelectorAll("[data-view]").forEach(node=>node.onclick=()=>change("view",node.dataset.view));
    document.querySelectorAll("[data-income-view]").forEach(node=>node.onclick=()=>change("incomeView",node.dataset.incomeView));
    $("examplesMenu").innerHTML=Object.entries(examples).map(([key,ex])=>`<button class="example-choice" data-example="${key}"><strong>${ex.title}</strong><span>${ex.subtitle}</span></button>`).join("");
    document.querySelectorAll("[data-example]").forEach(b=>b.onclick=()=>loadExample(b.dataset.example));
    $("examplesButton").onclick=()=>{const open=$("examplesMenu").hidden;$("examplesMenu").hidden=!open;$("examplesButton").setAttribute("aria-expanded",String(open));};
    $("tourButton").onclick=()=>showTour(0);
    $("closeDialog").onclick=closeDialog;
    $("infoDialog").addEventListener("click",e=>{if(e.target===$("infoDialog"))closeDialog();});
    $("infoDialog").addEventListener("close",()=>document.querySelectorAll(".tour-focus").forEach(n=>n.classList.remove("tour-focus")));
    $("policyHelp").onclick=()=>dialog(policyNames[p.policy],equations[p.policy]);
    $("phaseHelp").onclick=()=>dialog("Read the balance",`<p>The resource axis is bounded by 0–1. <strong>Orange participation</strong> counts actors whose exit threshold is below the resource density. <strong>Dashed blue sustainable participation</strong> is the share of ordered actors needed to balance renewal.</p><p>For y &lt; y*, participation is below the level required to balance renewal, so the resource recovers; for y &gt; y*, participation exceeds that level, so the resource declines.</p><p>The point shows the simulated endpoint. A marginal actor can supply a fraction of their potential at a threshold. The path consists of resampled points on the numerical trajectory; it starts from full resource and zero use for open access, or from the open-access attractor for policies.</p><p>Horizontal blue bars, when enabled, show impact mass by threshold-ordered rank. They are not a probability density of impact values. Use the Actors view to see actual impact potential against exit threshold.</p>`);
    $("pairingHelp").onclick=()=>dialog("A copula: who is paired with whom?",`<p>Two populations can have identical distributions of exit thresholds and impact potentials yet produce different outcomes. Their dependence determines whether the largest users exit early or remain active at low stock.</p><p>The pairing control changes the Gaussian copula's latent correlation. Negative values associate high impact potential with low exit thresholds; positive values associate high impact potential with high thresholds. The observed Pearson correlation can differ after lognormal transformations.</p><p>Ordered marginal quantiles and random samples represent the same distributional model. Ordered sampling reduces marginal sampling noise; it does not assume that all actors fall on a smooth one-dimensional line.</p><p>In the population builder, this dependence instead emerges from shared social conditions acting through w, q, and feasible effort.</p>`);
    $("methodsButton").onclick=methods;$("statusButton").onclick=diagnostics;
    $("settingsButton").onclick=()=>{
        dialog("Population & numerical settings",`<p>Population settings change the simulated actors. Path spacing only changes how densely the numerical trajectory is displayed.</p><div id="settingsForm" class="constant-grid"><label>Actors<input type="number" id="settingsN" min="24" max="1000" step="1" value="${p.n}" ${p.populationMode==="imported"?"disabled":""}></label><label>Random seed<input type="number" id="settingsSeed" min="1" max="99999" step="1" value="${p.seed}"></label><label>Response α<sub>i</sub><input type="number" id="settingsAlpha" min="0.001" max="0.3" step="0.005" value="${p.alpha}"></label><label>Path spacing<input type="number" id="settingsSpacing" min="0.001" max="0.2" step="0.001" value="${p.spacing}"></label><label>Solver<select id="settingsSolver"><option value="rk23" ${p.solver==="rk23"?"selected":""}>Adaptive RK23</option><option value="euler" ${p.solver==="euler"?"selected":""}>Euler (Δτ = 0.005)</option></select></label></div><p class="fine-print">The same response rate is assigned to every actor. The adaptive tolerance is 10<sup>−8</sup> absolute + 2 × 10<sup>−6</sup> relative per state. The maximum simulated time is 6000 ecological time units.</p><button id="applySettings" class="primary-button">Apply settings</button>`);
        $("applySettings").onclick=()=>{
            const fields=[["settingsN","n",24,1000],["settingsSeed","seed",1,99999],["settingsAlpha","alpha",.001,.3],["settingsSpacing","spacing",.001,.2]];
            for(const [id,key,lo,hi]of fields){const value=+$(id).value;if(!Number.isFinite(value)||value<lo||value>hi){toast(`Enter a value between ${lo} and ${hi}.`);$(id).focus();return;}p[key]=["n","seed"].includes(key)?Math.round(value):value;}
            p.solver=$("settingsSolver").value;closeDialog();simulate();
        };
    };
    $("instrumentButton").onclick=()=>change("scan",false);$("scanButton").onclick=()=>change("scan",true);
    $("statsButton").onclick=()=>{const show=$("distributionStats").hidden;$("distributionStats").hidden=!show;$("statsButton").setAttribute("aria-expanded",String(show));requestAnimationFrame(()=>data&&render());};
    $("causalButton").onclick=openCausal;$("closeCausal").onclick=closeCausal;$("drawerShade").onclick=closeCausal;
    $("resetCausal").onclick=()=>{draft=copy(SEDModel.causalDefaults);causalControls();previewCausal();};
    $("applyCausal").onclick=()=>{p.causal=copy(draft);p.populationMode="causal";p.view="actors";closeCausal();simulate();};
    $("directButton").onclick=()=>{p.populationMode="direct";p.records=undefined;simulate();};
    $("themeButton").onclick=()=>theme(document.body.dataset.theme==="dark"?"light":"dark");
    $("shareButton").onclick=share;
    $("resetButton").onclick=()=>{p=copy(SEDModel.defaults);history.replaceState(null,"",location.pathname+location.search);simulate();toast("Restored the initial population and open access");};
    $("exportButton").onclick=()=>{dialog("Keep the experiment",`<p>Save a reproducible scenario or the complete actor outcomes. Everything is generated locally in your browser.</p><div class="action-list"><button id="downloadScenario"><i data-lucide="file-json"></i>Scenario, parameters &amp; realized population (JSON)</button><button id="downloadActors"><i data-lucide="table-2"></i>Actor records &amp; income components (CSV)</button><button id="uploadScenario"><i data-lucide="upload"></i>Import a saved scenario or actor population</button></div>`);$("downloadScenario").onclick=exportScenario;$("downloadActors").onclick=exportActors;$("uploadScenario").onclick=()=>$("importFile").click();};
    $("importFile").onchange=async e=>{try{const doc=JSON.parse(await e.target.files[0].text());const parameters=doc.parameters||doc;p=validate(doc.realizedPopulation?{...parameters,records:doc.realizedPopulation,populationMode:"imported"}:parameters);closeDialog();simulate();toast("Scenario imported with its realized actor population");}catch(error){toast(`Could not import: ${error.message}`);}e.target.value="";};
    document.querySelectorAll(".save-plot").forEach(b=>b.onclick=()=>{const c=$(b.dataset.canvas),a=document.createElement("a");a.download=`SED_${b.dataset.canvas==="phaseCanvas"?"resource_balance":p.incomeView==="change"?"income_change":"income_distribution"}.png`;a.href=c.toDataURL("image/png");a.click();});
    const goals={resource:"Resource rent",total:"Total income",gini:"Gini",ecology:"Resource density",impact:"Policy impact"};
    $("goalWeights").innerHTML=Object.entries(goals).map(([k,label])=>`<label class="control"><span>${label} exponent</span><output id="weight-${k}-value">${p.weights[k].toFixed(2)}</output><input data-weight="${k}" type="range" min="-2" max="2" step="0.05" value="${p.weights[k]}"></label>`).join("");
    document.querySelectorAll("[data-weight]").forEach(n=>n.oninput=()=>{p.weights[n.dataset.weight]=+n.value;$("weight-"+n.dataset.weight+"-value").textContent=(+n.value).toFixed(2);n.style.setProperty("--progress",`${100*(+n.value+2)/4}%`);if(data)render();});
    for(const [canvasId,tooltipId]of [["phaseCanvas","phaseTooltip"],["incomeCanvas","incomeTooltip"]]) {
        const canvas=$(canvasId),tooltip=$(tooltipId);
        canvas.onpointermove=e=>{const rect=canvas.getBoundingClientRect(),x=e.clientX-rect.left,y=e.clientY-rect.top,hit=SEDPlots.hit(canvas,x,y);if(!hit){tooltip.hidden=true;return;}tooltip.innerHTML=`<strong>${escape(hit.title)}</strong>`+hit.values.map(([k,v])=>`<p><span>${escape(k)}</span><b>${escape(v)}</b></p>`).join("");tooltip.hidden=false;tooltip.style.left=`${Math.max(0,Math.min(rect.width-tooltip.offsetWidth,x+15))}px`;tooltip.style.top=`${Math.max(0,Math.min(rect.height-tooltip.offsetHeight,y+8))}px`;};
        canvas.onpointerleave=()=>tooltip.hidden=true;
    }
    document.addEventListener("keydown",e=>{
        if(e.key==="Escape"&&!$("causalDrawer").hidden)closeCausal();
        if(e.key==="Tab"&&!$("causalDrawer").hidden){const nodes=[...$("causalDrawer").querySelectorAll("button,input,summary")].filter(n=>n.getClientRects().length);const first=nodes[0],last=nodes[nodes.length-1];if(e.shiftKey&&document.activeElement===first){e.preventDefault();last.focus();}else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first.focus();}}
    });
    let resizeTimer;new ResizeObserver(()=>{clearTimeout(resizeTimer);resizeTimer=setTimeout(()=>{if(data)render();if(!$("causalDrawer").hidden)previewCausal();},80);}).observe(document.querySelector(".workspace"));
    try{const hash=new URLSearchParams(location.hash.slice(1));if(hash.has("scenario"))p=validate(JSON.parse(hash.get("scenario")));}catch(error){toast("This scenario link could not be loaded. Showing the initial population.");}
    let savedTheme="light";try{savedTheme=localStorage.getItem("sed-companion-theme")||"light";}catch{}
    theme(savedTheme);controls();icons();simulate();
    window.__SED={get params(){return copy(p);},get result(){return data;},set:(values)=>{p=validate({...p,...values});simulate();},render,validate};
})();
