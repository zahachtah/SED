#!/usr/bin/env julia

using CairoMakie
using SED

CairoMakie.activate!()

const S = SED

function causal_dependency_context(; N=200)
    data = (
        N=N,
        gender=S.dist(mean=0.5, distribution=S.Bernoulli, random=true),
        health=S.dist(mean=0, sigma=2.0, distribution=S.Normal,
            dependency_fun="1/(1+exp(-2-independent))"),
        parental=S.dist(min=0.1, max=4.0, distribution=S.LogNormal),
        time=S.dist(min=0.0, max=1.0,
            dependency_fun="clamp(health * (1 - 0.60*gender) * independent, 0, 1)"),
        efficiency=S.dist(min=0.015, max=0.20, normalize=false,
            dependency_fun="0.3 * ((1-gender) + 0.35*gender) * parental * independent"),
        opportunities=S.dist(min=0.1, max=1.6, distribution=S.LogNormal,
            dependency_fun="0.02 * parental * (1 - 0.4*gender) * independent"),
        r=0.08,
        K=0.8,
        fK=0.50,
        ū=S.dist(min=-0.1, max=0.1, dependency_fun="time * efficiency"),
        w̃=S.dist(min=-0.1, max=0.1,
            dependency_fun="(opportunities ./ (efficiency + 1e-6)) .+ independent"),
        α=S.dist(min=0.1, max=0.1, distribution=S.Uniform),
    )
    S.sample!(data, random=true)
    return data
end

function figure_causal_dependencies(; outdir=joinpath(@__DIR__, "figures"), save_outputs=true)
    data = causal_dependency_context()
    vars = [:gender, :health, :parental, :time, :efficiency, :opportunities, :ū, :w̃]
    labels = ["Gender", "Health", "Parental", "Time", "Efficiency", "Opport.", "Impact", "Thresholds"]

    fig = S.distribution_plot(data, vars;
        labels,
        corr=:spearman,
        cellsize=(180, 180),
        markersize=3,
        cmap=:coolwarm,
        reverse_cmap=true,
        dep_range=(1:4, 5:8))

    phase_ax = Axis(fig[5:6, 7:8];
        xlabel="Resource level",
        ylabel="Participation (fraction)",
        yaxisposition=:right,
        title="Open access")
    hidespines!(phase_ax)
    hidedecorations!(phase_ax)
    S.phase_plot!(phase_ax, S.sim(S.scenario(data)))

    paths = String[]
    if save_outputs
        isdir(outdir) || mkpath(outdir)
        png = joinpath(outdir, "causal_dependencies.png")
        pdf = joinpath(outdir, "causal_dependencies.pdf")
        save(png, fig)
        save(pdf, fig)
        append!(paths, [png, pdf])
    end
    return fig, paths
end

if abspath(PROGRAM_FILE) == @__FILE__
    _, paths = figure_causal_dependencies()
    println("Wrote:")
    foreach(path -> println("  ", path), paths)
end
