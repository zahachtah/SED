#!/usr/bin/env julia

# Compare two TUR supply formulations: aggregate clamp vs element-wise clamp.
# Saves a small figure and prints stability hints.

if !isdefined(Main, :SED)
    include(joinpath(@__DIR__, "..", "SED.jl"))
end
using .SED

using CairoMakie

function ϕ_sumclamp(dx, x, p, t)
    # aggregate clamp: clamp(sum(R - usage), 0, Inf)
    supply = if p.policy_target == :yield
        clamp(sum(p.R .- (x[1:p.N] .* x[p.N+1])), 0.0, Inf)
    else
        max(0.0, sum(p.R .- x[1:p.N]))
    end
    id = findall(dx[1:p.N] .> 0.0)
    if p.policy_target == :yield
        max_extra_yield = (p.ū[id] .- x[id]) .* x[p.N+1]
        desired_extra_yield = dx[id] .* x[p.N+1]
        ind_demand = min.(max_extra_yield, desired_extra_yield)
    else
        ind_demand = min.(p.ū[id] .- x[id], dx[id])
    end
    demand = sum(ind_demand)
    dx[p.N+2] = p.market_rate * (demand - supply)
    if demand > supply
        dx[id] .= supply .* ind_demand ./ demand
    end
end

function ϕ_sumofclamps(dx, x, p, t)
    # element-wise clamp then sum: sum(clamp.(R - usage, 0, Inf))
    supply = if p.policy_target == :yield
        sum(clamp.(p.R .- (x[1:p.N] .* x[p.N+1]), 0.0, Inf))
    else
        sum(clamp.(p.R .- x[1:p.N], 0.0, Inf))
    end
    id = findall(dx[1:p.N] .> 0.0)
    if p.policy_target == :yield
        max_extra_yield = (p.ū[id] .- x[id]) .* x[p.N+1]
        desired_extra_yield = dx[id] .* x[p.N+1]
        ind_demand = min.(max_extra_yield, desired_extra_yield)
    else
        ind_demand = min.(p.ū[id] .- x[id], dx[id])
    end
    demand = sum(ind_demand)
    dx[p.N+2] = p.market_rate * (demand - supply)
    if demand > supply
        dx[id] .= supply .* ind_demand ./ demand
    end
end

function build_tur(s; target=:effort, market_rate=0.05, variant::Symbol=:sumclamp)
    kit = SED.tradable_use_rights_kit(; target, market_rate)
    ϕv = variant === :sumclamp ? ϕ_sumclamp : ϕ_sumofclamps
    return SED.with_policy(s; kit..., ϕ=ϕv)
end

function run_compare(; N=120, target=:effort, f=nothing, t_end=1000.0, scenario_kind::Symbol=:high_impact)
    # Use a scenario that tends to sustain positive price
    base0 = scenario_kind === :high_impact ? SED.scenario(SED.high_impact(N=N)) : SED.scenario(SED.base(N=N))
    # Choose a regulation level that tends to keep price > 0
    # Effort target: MSY around ~0.5 (allowed effort sum ≈ 1 - f). Use f≈0.5 by default.
    # Yield target: MSY around ~0.25 (allowed yield sum ≈ 1 - f). Use f≈0.75 by default.
    f_chosen = f === nothing ? (target === :effort ? 0.5 : 0.75) : f
    s_agg = build_tur(base0; target, variant=:sumclamp)
    s_elem = build_tur(base0; target, variant=:sumofclamps)
    sol_agg = SED.sim(s_agg; regulation=f_chosen, t_end)
    sol_elem = SED.sim(s_elem; regulation=f_chosen, t_end)

    # Price traces
    fig = Figure(size=(900, 380))
    ax1 = Axis(fig[1,1], title="Price over time — aggregate clamp")
    ax2 = Axis(fig[1,2], title="Price over time — element-wise clamp")
    lines!(ax1, sol_agg.t[1:end-1], [u[end] for u in sol_agg.u[1:end-1]])
    lines!(ax2, sol_elem.t[1:end-1], [u[end] for u in sol_elem.u[1:end-1]])
    outdir = joinpath(@__DIR__, "figures"); isdir(outdir) || mkpath(outdir)
    path = joinpath(outdir, "tur_supply_compare_$(String(target))_f$(replace(string(f_chosen), "."=>"p")).png")
    save(path, fig)

    # Phase plots
    fig2 = Figure(size=(900, 380))
    pax1 = Axis(fig2[1,1], title="Phase — aggregate clamp")
    pax2 = Axis(fig2[1,2], title="Phase — element-wise clamp")
    SED.phase_plot!(pax1, sol_agg)
    SED.phase_plot!(pax2, sol_elem)
    path2 = joinpath(outdir, "tur_supply_phase_$(String(target))_f$(replace(string(f_chosen), "."=>"p")).png")
    save(path2, fig2)

    println("Target=$(target)  regulation f=$(round(f_chosen, digits=2))")
    println("Saved figures:\n  ", path, "\n  ", path2)
    return (; sol_agg, sol_elem, price_plot=path, phase_plot=path2, f=f_chosen)
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_compare(; N=120, target=:yield, scenario_kind=:high_impact)
    run_compare(; N=120, target=:effort, scenario_kind=:high_impact)
end
